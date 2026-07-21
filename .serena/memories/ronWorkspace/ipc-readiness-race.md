# IPC Readiness in Zellij/Alacritty Setup — Corrected Analysis

## Key Finding: `query-tab-names` Always Returns Exit Code 0

**Critical discovery**: `zellij --session <name> action query-tab-names` returns
exit code 0 **even when the session does not exist**. Zellij considers reaching
the daemon as success; if the daemon reports "session not found," that's still
exit code 0.

This means `query-tab-names` **cannot be used as a readiness check** via exit
code — it always passes immediately, making the script skip the wait and hit
the daemon before the session is registered.

## Output-Based Probe Breakthrough

Although exit codes are useless, **output content differs reliably**:

| Condition | `query-tab-names` stdout |
|-----------|--------------------------|
| Session exists + ready | Tab names, one per line (no ANSI codes, no brackets) |
| Session doesn't exist | Full `list-sessions` output (ANSI codes, `[Created ...]` timestamps) |
| Session exists but EXITED | Full `list-sessions` output (same fallback) |

This means checking for `[Created` in the output is a reliable probe:

```bash
# Session is action-ready when output is tab names (no [Created)
probe_out=$(zellij --session "$session_name" action query-tab-names 2>/dev/null) || true
if ! echo "$probe_out" | grep -qF '[Created'; then
  # Session responded with tab names → action-ready
fi
```

## Three-Part Fix in `launch_term` (July 2026)

The `launch_term` function in `lighter-dev.bash` was fixed with three changes:

### 1. Delete-Wait Loop (Step 2)
After `delete-session --force`, poll `list-sessions` until the stale session
name is **gone** from the listing. The delete is normally synchronous, but
on loaded systems or when the daemon must clean up EXITED metadata, the
session name may linger briefly. Waiting for its absence guarantees a clean
slate before creating a new session with the same name.

```bash
local delete_timeout=$SESSION_READY_TIMEOUT
while ((delete_timeout > 0)); do
  if ! zellij list-sessions 2>/dev/null | ... | grep -qxF "$session_name"; then
    break
  fi
  sleep 1
  ((delete_timeout--))
done
```

### 2. EXITED Session Filter (Step 5 readiness check)
The original readiness check matched **any** session — including EXITED ones.
An EXITED session cannot accept actions (`new-tab`, `close-tab`, etc.), so
matching one causes the wait loop to break early and all subsequent actions
to fail with "Session not found."

Fix: add `grep -v '(EXITED'` before the awk/grep pipeline to only match
ACTIVE sessions.

```bash
if zellij list-sessions 2>/dev/null |
  sed 's/\x1b\[[0-9;]*m//g' |
  grep -v '(EXITED' |
  awk '{print $1}' |
  grep -qxF "$session_name"; then
  break
fi
```

### 3. Action-Readiness Probe (Step 6)
Even for an ACTIVE session, there's a brief gap between when the daemon lists
it and when the session server finishes initialization and can process actions.
The old `sleep 1` heuristic was insufficient on loaded systems.

Replace it with a **content-based probe**: call `query-tab-names` and check
whether the output contains `[Created` (indicating the fallback
`list-sessions` output, meaning the session doesn't respond yet). Retry up
to 3 times with 1-second delays.

```bash
for probe_try in 1 2 3; do
  action_probe=$(zellij --session "$session_name" action query-tab-names 2>/dev/null) || true
  if ! echo "$action_probe" | grep -qF '[Created'; then
    break
  fi
  sleep 1
done
if echo "$action_probe" | grep -qF '[Created'; then
  log_warn "Session not responding to actions (tried 3 probes)"
  return 0
fi
```

This eliminated the `sleep 1` that previously sat between the readiness check
and tab creation, replacing it with an adaptive polling loop that waits only
as long as necessary (usually 0 retries — the session is ready on first probe).

## Correct Readiness Check

The only reliable way to check if a session exists and is active is via
`list-sessions | grep` with an EXITED filter:

```bash
# CORRECT: returns non-zero when session not found or EXITED
zellij list-sessions 2>/dev/null |
  sed 's/\x1b\[[0-9;]*m//g' |
  grep -v '(EXITED' |
  awk '{print $1}' |
  grep -qxF "$session_name"

# BROKEN: always returns 0 (session found or not)
zellij --session "$session_name" action query-tab-names &>/dev/null
```

## Remaining Limitations

1. **Daemon overload on session-count explosion** — With 30+ EXITED sessions
   accumulated (from previous runs), `list-sessions` output grows large.
   Consider periodic cleanup with `zellij delete-session --force` on old
   EXITED sessions.
2. **X11 window manager saturation** — 3+ Alacritty windows on the same
   desktop in sequence may trigger WM focus/layout bugs (not Zellij-related).
3. **`setsid` + `$!` PID tracking** — `$!` after `setsid cmd &` captures
   `setsid`'s PID, not the inner command's PID. The `kill -0` check works
   because `setsid` waits for the child, but timing could be tight on
   overloaded systems.

## Practical Rules for Zellij CLI Scripting

1. **Use `list-sessions | grep -v '(EXITED' | awk '{print $1}' | grep -xF "$name"`**
   for session existence checks. Do NOT use `action query-tab-names` for
   readiness.
2. **Use `query-tab-names` output content** (`[Created` absence) for
   action-readiness probing — exit codes are always 0.
3. **Wait for deletion to propagate** before creating a session with the same
   name. Poll `list-sessions` for the name's absence.
4. **`query-tab-names` IS safe for post-creation verification** — once you
   KNOW the session exists (confirmed via list-sessions), querying tab names
   reveals whether tabs were actually created.
5. **`setsid` is still recommended** for process detachment from shell.
6. **`|| true` should not hide tab failures** — count them and warn.
