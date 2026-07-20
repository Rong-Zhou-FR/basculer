# IPC Readiness in Zellij/Alacritty Setup — Corrected Analysis

## Key Finding: `query-tab-names` Always Returns Exit Code 0

**Critical discovery**: `zellij --session <name> action query-tab-names` returns
exit code 0 **even when the session does not exist**. Zellij considers reaching
the daemon as success; if the daemon reports "session not found," that's still
exit code 0.

This means `query-tab-names` **cannot be used as a readiness check** via exit
code — it always passes immediately, making the script skip the wait and hit
the daemon before the session is registered.

## Correct Readiness Check

The only reliable way to check if a session exists is via
`list-sessions | grep`, which correctly returns non-zero when absent:

```bash
# CORRECT: returns non-zero when session not found
zellij list-sessions 2>/dev/null |
  sed 's/\x1b\[[0-9;]*m//g' |
  awk '{print $1}' |
  grep -qxF "$session_name"

# BROKEN: always returns 0 (session found or not)
zellij --session "$session_name" action query-tab-names &>/dev/null
```

## Remaining Uncertainty

Even with the correct readiness check (`list-sessions + grep`), the `rzdoi`
terminal (last of 3 on desktop 4, 8th of 9 total) sometimes fails to appear.
The root cause of this specific failure is still unclear. Candidates:

1. **Zellij daemon overload** — with 7+ sessions already active, the daemon
   may be slow to process `new-tab` for the 8th session, and the `sleep 0.5`
   between readiness and tab creation is insufficient.
2. **X11 window manager saturation** — 3 Alacritty windows on the same
   desktop in sequence may trigger WM focus/layout bugs.
3. **Race within `setsid` + `$!` PID tracking** — `$!` after
   `setsid cmd &` captures `setsid`'s PID, not the inner command's PID.
   The `kill -0` check works because `setsid` waits for the child, but on
   overloaded systems the timing could be tight.

## Diagnostics Added

- Session registration timing logged if it takes >2s
- Tab creation success/failure counted per session
- Namespace switched from `testing` to `lighter-config`

## Practical Rules for Zellij CLI Scripting

1. **Use `list-sessions | awk '{print $1}' | grep -xF "$name"`** for session
   existence checks. Do NOT use `action query-tab-names` for readiness.
2. **`query-tab-names` IS safe for post-creation verification** — once you
   KNOW the session exists (confirmed via list-sessions), querying tab names
   reveals whether tabs were actually created.
3. **Always add `sleep 0.5` after session registration** — a heuristic, but
   necessary because list-sessions and action-ready may still have a gap.
4. **`setsid` is still recommended** for process detachment from shell.
5. **`|| true` should not hide tab failures** — count them and warn.
