#!/usr/bin/env bash
#
# lighter-dev.bash — Launch the lighter-system development workspace
#
# IMPORTANT: This script closes and reopens ALL terminals across multiple
# virtual desktops, forcefully killing existing Zellij sessions. It WILL
# disrupt any work-in-progress (editors, running commands, etc.). An LLM
# must NEVER execute a live run of this script without first obtaining
# explicit, informed permission from the user. Use `--dry-run` for preview.
#
# Opens Alacritty+Zellij terminals across multiple Linux virtual desktops,
# each pre-configured with project directories and startup commands.
# Designed for the lighter-system development workflow.
#
# Workspace layout:
#   WS 1 (desk 0) — 1 terminal, 8 tabs:
#     lighter-config:   nvim README.md | shell | lighterbird (git pull)
#                       | fe (web) | shell | semantika (git pull) | fe (web) | shell
#   WS 2 (desk 1) — 1 terminal, 3 tabs:
#     ronzz-markmap:     shell | email-write (ls) | diary-write (ls)
#   WS 3 (desk 2) — 1 terminal, 3 tabs:
#     autish:           A repl sistemo | shell | A repl semantika
#   WS 4 (desk 3) — 2 terminals:
#     basculer:         basculer-LLM (opencode) | shell | opencode-config-LLM (opencode)
#                       | shell | opencode-agents (ls) | opencode-commands (ls)
#     scratch:          nvim tmp.md | nvim lighterbird-1.md | nvim semantika-1.md
#   WS 5 (desk 4) — 3 terminals:
#     lighterbird:      gitmaster | opencode | shell
#     semantika:        gitmaster | opencode | opencode (builtin) | shell
#     ronzzdoi:         gitmaster | opencode | shell
#   WS 12 (desk 11) — 1 terminal, 3 tabs:
#     france-en-chiffres: opencode | shell | content
#
# Prerequisites:
#   - alacritty       terminal emulator
#   - zellij (>=0.40) terminal multiplexer
#   - wmctrl          virtual desktop switching (X11; skipped on Wayland)
#
# Customization:
#   Edit the "CONFIGURATION" section below to match your paths and commands.
#
# Usage:
#   ./lighter-dev.bash                launch the workspace
#   ./lighter-dev.bash --help         show this message
#   ./lighter-dev.bash --dry-run      preview without launching

set -euo pipefail

# ═════════════════════════════════════════════════════════════════════════════
# CONFIGURATION — edit these to match your setup
# ═════════════════════════════════════════════════════════════════════════════

# ── Project directories ────────────────────────────────────────────────────
DIR_LIGHTER_CONFIG="$HOME/kodo/lighter-config"
DIR_LIGHTERBIRD="$HOME/kodo/autish/lighterbird"
DIR_SEMANTIKA="$HOME/kodo/autish/semantika"
DIR_BASCULER="$HOME/kodo/basculer"
DIR_SCRATCH="$HOME/scratch"
DIR_AUTISH="$HOME/kodo/autish"
DIR_FEC="$HOME/kodo/france-en-chiffres"
DIR_RONZZMARKMAP="$HOME/kodo/ronzz-markmap"
DIR_RONZZDOI="$HOME/kodo/autish/ronzzdoi"

# ── OpenCode shared server (serve+attach) ───────────────────────────────
# Instead of starting N independent opencode servers (one per tab), start
# ONE headless server and have all tabs attach to it. This saves ~3-4x
# memory (one Bun/Node runtime instead of N).
# https://opencode.ai/docs/cli#attach
OPCODE_SERVE_PORT=4096
OPCODE_SERVE_URL="http://127.0.0.1:${OPCODE_SERVE_PORT}"
OPCODE_DAEMON_LOG="/tmp/opencode-daemon.log"
OPCODE_DAEMON_PID_FILE="/tmp/opencode-daemon.pid"

# ── Custom commands (must be on PATH or defined in bashrc) ─────────────────
# NOTE: These are used as prefixes — each tab appends "--dir $TAB_DIR".
# Attach mode connects to the shared server instead of spawning a new one.
# --mini is only supported by `opencode attach`, not `opencode run`.
# The gitmaster agent can be activated inside any session via '/agent gitmaster'.
CMD_OPENCODE="opencode attach ${OPCODE_SERVE_URL}"
CMD_MASTER="env OPENCODE_CONFIG_CONTENT='{\"default_agent\":\"gitmaster\"}' opencode attach ${OPCODE_SERVE_URL} --mini"
CMD_A_REPL_SISTEMO="A repl sistemo"
CMD_A_REPL_SEMANTIKA="A repl semantika"

# ── Virtual desktop mapping (1-indexed workspace → 0-indexed wmctrl) ──────
# Change the list below if your desktop manager uses a different numbering.
for ws in 1 2 3 4 5 12; do
  declare "DESK_WS${ws}=$((ws - 1))"
done

# ── Floorp browser ─────────────────────────────────────────────────────────
# If floorp is not running when the workspace launches, start it so its
# built-in session restore reopens previous windows on their desktops.
# The script launches floorp before creating terminals so windows settle
# before Alacritty windows take focus.
FLOORP_BIN="${FLOORP_BIN:-floorp}"
FLOORP_PROFILE="" # empty = default profile
# Seconds to wait after launching floorp for windows to appear.
FLOORP_WAIT=4

# ── Timing ─────────────────────────────────────────────────────────────────
# Seconds to wait between terminal launches (allows windows to appear).
LAUNCH_DELAY=1.5

# ═════════════════════════════════════════════════════════════════════════════
# END CONFIGURATION
# ═════════════════════════════════════════════════════════════════════════════

# ── Constants ──────────────────────────────────────────────────────────────
SELF="$(basename "${BASH_SOURCE[0]}")"
HAS_WMCTRL=false
command -v wmctrl &>/dev/null && HAS_WMCTRL=true

# Seconds to wait for a Zellij session daemon to start after launch.
SESSION_READY_TIMEOUT=15

# Seconds to wait for zellij delete-session --force to propagate.
DELETE_TIMEOUT=3

# ── Helpers ────────────────────────────────────────────────────────────────

log_info() { printf '\e[34m[INFO]\e[0m  %s\n' "$*"; }
log_ok() { printf '\e[32m[OK]\e[0m    %s\n' "$*"; }
log_warn() { printf '\e[33m[WARN]\e[0m  %s\n' "$*"; }
log_err() { printf '\e[31m[ERROR]\e[0m %s\n' "$*" >&2; }

need_cmd() {
  if ! command -v "$1" &>/dev/null; then
    log_err "$1 is required but not found on PATH."
    log_err "Install it and try again."
    exit 1
  fi
}

need_dir() {
  if [[ ! -d "$1" ]]; then
    log_err "Directory not found: $1"
    log_err "Check the CONFIGURATION section in $SELF."
    exit 1
  fi
}

# Run a command, discard stdout, capture stderr, log warning on failure.
# Usage: run_captured <label> <command> [args...]
# Returns the exit code of the command.
run_captured() {
  local label="$1"
  shift
  local err_output
  err_output=$("$@" 2>&1 >/dev/null) && return 0
  log_warn "${label}: ${err_output:-"(no stderr output)"}"
  return 1
}

switch_desktop() {
  local desk_index="$1"
  if $HAS_WMCTRL; then
    wmctrl -s "$desk_index" 2>/dev/null || true
    # Poll until the switch takes effect (wmctrl -d shows '*' on the target).
    # This handles window managers with asynchronous desktop switching.
    local settle=0
    while (( settle < 20 )); do
      if wmctrl -d 2>/dev/null | awk '$2 == "*" {print $1; exit}' | grep -qxF "$desk_index" 2>/dev/null; then
        break
      fi
      sleep 0.1
      ((settle++)) || true
    done
  fi
}

# Launch a development workspace terminal.
#
# Approach:
#   1. Delete any stale session with the target name (clean slate)
#   2. Verify deletion fully processed (session gone from list-sessions)
#   3. Switch to target virtual desktop
#   4. Launch bare Zellij in Alacritty — default config loads, full UX frame
#   5. Wait for session registration via list-sessions (ACTIVE only, not EXITED)
#   6. Verify session responds to actions (query-tab-names output probe)
#   7. For each tab spec, create a new tab via `zellij action new-tab --cwd`
#   8. Close the auto-created default tab (best-effort)
#   9. Verify tab count via query-tab-names; retry any missing tabs
#
# Usage: launch_term <desk-index> <label> <tab-spec>...
# Each <tab-spec> is "tab_name|workdir|command"
# If command is empty, opens a shell in workdir.
launch_term() {
  local desk_index="$1"
  local label="$2"
  shift 2
  local -a tab_specs=("$@")
  local session_name="lighter-dev-${label}"
  local t_start

  log_info "Launching «${label}» on desktop $((desk_index + 1)) …"

  # Step 0: Preemptively clean all lighter-dev-* EXITED sessions from the
  # Zellij daemon.  These accumulate over runs (the daemon preserves EXITED
  # metadata for "resurrection") and can cause stale-name collisions or slow
  # down list-sessions.  Best-effort, ignore failures — don't touch ACTIVE
  # sessions (they're in use).
  zellij list-sessions 2>/dev/null |
    sed 's/\x1b\[[0-9;]*m//g' |
    grep '(EXITED' |
    awk '{print $1}' |
    grep '^lighter-dev-' |
    while IFS= read -r stale_sid; do
      zellij delete-session --force "$stale_sid" 2>/dev/null || true
    done || true

  # Step 1: Delete stale session (clean slate)
  run_captured "delete-session ${session_name}" \
    zellij delete-session --force "$session_name" || true

  # Step 2: Wait for deletion to propagate — after delete-session --force,
  # the daemon needs to fully remove the session before we create a new one
  # with the same name. Poll list-sessions until the name disappears.
  # Only wait for ACTIVE sessions — EXITED metadata that wasn't fully cleaned
  # is harmless: Step 4's `zellij --session` will resurrect it.
  local delete_timeout=$DELETE_TIMEOUT
  while ((delete_timeout > 0)); do
    if ! zellij list-sessions 2>/dev/null |
      sed 's/\x1b\[[0-9;]*m//g' |
      grep -v '(EXITED' |
      awk '{print $1}' |
      grep -qxF "$session_name"; then
      break  # stale session fully removed
    fi
    sleep 1
    ((delete_timeout--))
  done
  if ((delete_timeout == 0)); then
    local diag_state
    diag_state=$(zellij list-sessions 2>/dev/null |
      sed 's/\x1b\[[0-9;]*m//g' |
      awk -v name="$session_name" '$1 == name {sub(/^[^ ]* /, ""); print; exit}' || true)
    log_warn "Stale session «${session_name}» not removed within ${DELETE_TIMEOUT}s — proceeding"
    if [[ -n "$diag_state" ]]; then
      log_warn "  list-sessions shows: ${diag_state}"
    fi
  fi

  # Step 3: Switch to target virtual desktop
  switch_desktop "$desk_index"

  # Step 4: Launch bare Zellij via Alacritty — full UX frame from default config
  # Use setsid to detach from the shell session (survives script exit/SIGHUP).
  setsid alacritty -e zellij --session "$session_name" >/dev/null 2>/tmp/lighter-dev-alacritty-${label}.log &
  local alacritty_pid=$!

  # Quick check: did alacritty start?
  sleep 0.3
  if ! kill -0 "$alacritty_pid" 2>/dev/null; then
    log_warn "Alacritty exited immediately for «${label}»"
    log_warn "  Check: $(cat /tmp/lighter-dev-alacritty-${label}.log 2>/dev/null || echo "no log")"
    rm -f /tmp/lighter-dev-alacritty-${label}.log
    return 0
  fi

  # Step 5: Wait for the session to be registered with the Zellij daemon.
  # Poll list-sessions — EXITED sessions cannot accept actions, so filter them
  # out with grep -v '(EXITED'.
  t_start=${EPOCHSECONDS:-$(date +%s)}
  local timeout=$SESSION_READY_TIMEOUT
  while ((timeout > 0)); do
    if zellij list-sessions 2>/dev/null |
      sed 's/\x1b\[[0-9;]*m//g' |
      grep -v '(EXITED' |
      awk '{print $1}' |
      grep -qxF "$session_name"; then
      break
    fi
    sleep 1
    ((timeout--)) || true
  done

  local t_elapsed=$(( $(date +%s) - t_start ))
  if ((timeout == 0)); then
    log_warn "Session «${session_name}» not registered within ${SESSION_READY_TIMEOUT}s (${t_elapsed}s waited)"
    log_warn "  Alacritty log: $(cat /tmp/lighter-dev-alacritty-${label}.log 2>/dev/null || echo "empty")"
    rm -f /tmp/lighter-dev-alacritty-${label}.log
    return 0
  fi
  rm -f /tmp/lighter-dev-alacritty-${label}.log
  [[ "$t_elapsed" -gt 2 ]] && log_info "Session «${session_name}» ready after ${t_elapsed}s"

  # Step 6: Verify the session responds to actions before creating tabs.
  # query-tab-names returns tab names (one per line) against an active session,
  # but falls through to full list-sessions output (with [Created timestamps)
  # when the session does not exist or is not ready. Probe up to 3 times.
  local action_probe
  for probe_try in 1 2 3; do
    action_probe=$(zellij --session "$session_name" action query-tab-names 2>/dev/null) || true
    if ! echo "$action_probe" | grep -qF '[Created'; then
      break  # session responded with tab names
    fi
    sleep 1
  done
  if echo "$action_probe" | grep -qF '[Created'; then
    log_warn "Session «${session_name}» registered but not responding to actions (tried 3 probes)"
    return 0
  fi

  # Step 7: Create each tab via `zellij action new-tab`
  # Each new tab inherits the session's UX frame (tab-bar, status-bar).
  # Shell-only tabs: just set name and cwd.
  # Command tabs: wrap in `bash -c "cmd; exec bash"` to keep pane open.
  local tab_name workdir cmd t_created=0 t_failed=0
  for spec in "${tab_specs[@]}"; do
    IFS='|' read -r tab_name workdir cmd <<<"$spec"
    if [[ -z "$cmd" ]]; then
      run_captured "new-tab ${tab_name}" \
        zellij --session "$session_name" action new-tab \
        --name "$tab_name" --cwd "$workdir" && \
        t_created=$((t_created + 1)) || t_failed=$((t_failed + 1))
    else
      run_captured "new-tab ${tab_name}" \
        zellij --session "$session_name" action new-tab \
        --name "$tab_name" --cwd "$workdir" \
        -- bash -c "$cmd; exec bash" && \
        t_created=$((t_created + 1)) || t_failed=$((t_failed + 1))
    fi
  done
  if (( t_failed > 0 )); then
    log_warn "Session «${session_name}»: ${t_created} tabs created, ${t_failed} failed"
  fi

  # Step 8: Close the auto-created default tab (best-effort)
  run_captured "go-to-tab 0" \
    zellij --session "$session_name" action go-to-tab 0 || true
  run_captured "close-tab" \
    zellij --session "$session_name" action close-tab || true

  # Step 9: Verify tab count — retry any missing tabs
  # query-tab-names outputs one name per line; count non-empty lines.
  local expected_count="${#tab_specs[@]}"
  local actual_names actual_count missing_count=0
  actual_names=$(zellij --session "$session_name" action query-tab-names 2>/dev/null) || true
  actual_count=$(echo "$actual_names" | grep -c . || true)
  if (( actual_count < expected_count )); then
    log_warn "Session «${session_name}»: ${actual_count}/${expected_count} tabs. Retrying missing..."
    for spec in "${tab_specs[@]}"; do
      IFS='|' read -r tab_name workdir cmd <<<"$spec"
      if ! echo "$actual_names" | grep -qxF "$tab_name" 2>/dev/null; then
        if [[ -z "$cmd" ]]; then
          run_captured "retry-tab ${tab_name}" \
            zellij --session "$session_name" action new-tab \
            --name "$tab_name" --cwd "$workdir" || true
        else
          run_captured "retry-tab ${tab_name}" \
            zellij --session "$session_name" action new-tab \
            --name "$tab_name" --cwd "$workdir" \
            -- bash -c "$cmd; exec bash" || true
        fi
        missing_count=$((missing_count + 1))
      fi
    done
    if (( missing_count > 0 )); then
      log_info "Retried ${missing_count} missing tab(s) for «${session_name}»."
      # Second-verification pass
      local verify_count
      verify_count=$(zellij --session "$session_name" action query-tab-names 2>/dev/null | grep -c . || true)
      if (( verify_count < expected_count )); then
        log_warn "After retry: ${verify_count}/${expected_count} tabs in «${session_name}»."
        log_warn "Manually inspect with: zellij attach '${session_name}'"
      fi
    fi
  fi
}

# ── Floorp restore ─────────────────────────────────────────────────────────
#
# If Floorp is not running, launch it so its built-in session restore
# reopens previous windows.  We do this *before* the terminal barrage so
# browser windows have time to appear before Alacritty takes focus.
restore_floorp() {
  local floorp_pid

  # ── Check if already running ──────────────────────────────────────────────
  floorp_pid="$(pgrep -x -u "$(id -u)" "$(basename "${FLOORP_BIN}")" 2>/dev/null || true)"
  if [[ -n "$floorp_pid" ]]; then
    log_info "Floorp already running (PID $floorp_pid) — skipping restore"
    return 0
  fi

  log_info "Floorp not running — launching for session restore …"

  # ── Build launch command ──────────────────────────────────────────────────
  local -a launch_args=()
  if [[ -n "$FLOORP_PROFILE" ]]; then
    launch_args+=(-P "$FLOORP_PROFILE")
  fi

  # Launch detached (setsid so it survives the shell session).
  # Floorp's built-in session restore will reopen previous windows.
  setsid "$FLOORP_BIN" "${launch_args[@]}" >/dev/null 2>/tmp/lighter-dev-floorp.log &
  local floorp_pid_new=$!

  # Quick check: did floorp start?
  sleep 0.5
  if ! kill -0 "$floorp_pid_new" 2>/dev/null; then
    log_err "Floorp exited immediately after launch!"
    log_err "  Check: $(cat /tmp/lighter-dev-floorp.log 2>/dev/null || echo "no log")"
    rm -f /tmp/lighter-dev-floorp.log
    return 1
  fi

  log_info "Waiting ${FLOORP_WAIT}s for Floorp windows to appear (PID $floorp_pid_new) …"
  sleep "$FLOORP_WAIT"

  # ── Count restored windows ────────────────────────────────────────────────
  local win_count
  win_count="$(wmctrl -l 2>/dev/null | grep -ic "ablaze floorp\|floorp\|mozilla firefox" || true)"
  if [[ "$win_count" -gt 0 ]]; then
    log_ok "Floorp restored — $win_count window(s) detected"
  else
    log_warn "Floorp launched (PID $floorp_pid_new) but no windows detected via wmctrl"
    log_warn "  Log: $(cat /tmp/lighter-dev-floorp.log 2>/dev/null || echo "empty")"
    log_warn "(Session restore may be pending, or wmctrl not available)"
  fi
  rm -f /tmp/lighter-dev-floorp.log
}

# ── OpenCode daemon ──────────────────────────────────────────────────────

# Start the shared `opencode serve` daemon. All Zellij tabs will attach
# to this single instance, sharing the Bun/Node.js runtime, LLM connections,
# and MCP infrastructure — instead of each tab spawning its own ~600MB server.
launch_opencode_daemon() {
  # ── Port-based detection (primary) ──────────────────────────────────
  # ss -tlnp shows listening TCP sockets with owning PID.  This is more
  # reliable than PID-file-only checks because the port binding is the
  # ground truth — if the daemon is alive, its port is bound.
  local port_pid
  port_pid=$(ss -tlnp 2>/dev/null \
    | grep -F ":${OPCODE_SERVE_PORT}" \
    | grep -o 'pid=[0-9][0-9]*' \
    | grep -o '[0-9][0-9]*' \
    || true)
  if [[ -n "$port_pid" ]]; then
    # Port is held — verify the owning process is opencode
    if ps -p "$port_pid" -o comm= 2>/dev/null | grep -qxF 'opencode'; then
      # Update PID file even if it was missing/stale
      echo "$port_pid" > "$OPCODE_DAEMON_PID_FILE"
      log_info "OpenCode server daemon already running (PID $port_pid)"
      return 0
    fi
    log_warn "Port ${OPCODE_SERVE_PORT} is held by non-opencode process"
    log_warn "  (PID $port_pid: $(ps -p "$port_pid" -o comm= 2>/dev/null || echo 'unknown'))"
    log_warn "  The opencode daemon cannot start until that process releases the port."
    return 1
  fi

  # ── PID-file fallback (for systems without ss(8)) ───────────────────
  # If the PID file points to a process that exists but isn't on our
  # port (recycled PID), don't trust it — clean up and restart.
  if [[ -f "$OPCODE_DAEMON_PID_FILE" ]]; then
    local existing_pid
    existing_pid=$(cat "$OPCODE_DAEMON_PID_FILE" 2>/dev/null || true)
    if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" 2>/dev/null; then
      rm -f "$OPCODE_DAEMON_PID_FILE"
    fi
  fi

  # ── Start daemon ────────────────────────────────────────────────────
  log_info "Starting OpenCode server daemon on port ${OPCODE_SERVE_PORT} …"
  setsid opencode serve --port "$OPCODE_SERVE_PORT" > "$OPCODE_DAEMON_LOG" 2>&1 &
  local daemon_pid=$!
  echo "$daemon_pid" > "$OPCODE_DAEMON_PID_FILE"

  # Poll until the server health endpoint responds
  local timeout=15
  while ((timeout > 0)); do
    if curl -sf "${OPCODE_SERVE_URL}/global/health" >/dev/null 2>&1; then
      log_ok "OpenCode server daemon ready (PID $daemon_pid)"
      return 0
    fi
    sleep 1
    ((timeout--)) || true
  done

  log_err "OpenCode server daemon not ready after 15s"
  log_err "  Check: ${OPCODE_DAEMON_LOG}"
  return 1
}

# ── Main ───────────────────────────────────────────────────────────────────

main() {
  case "${1:-}" in
  --help | -h)
    sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
    exit 0
    ;;
  --dry-run | --dry)
    log_warn "Dry run — no terminals will be launched."
    echo ""
    log_info "Would launch workspace 1 (desk $((DESK_WS1 + 1))):"
    log_info "  lighter-config:  nvim README.md | shell"
    log_info "  lighterbird:     git pull       | shell"
    log_info "  semantika:       git pull       | shell"
    echo ""
    log_info "Would launch workspace 2 (desk $((DESK_WS2 + 1))):"
    log_info "  ronzz-markmap:    shell | email-write (ls) | diary-write (ls)"
    echo ""
    log_info "Would launch workspace 3 (desk $((DESK_WS3 + 1))):"
    log_info "  autish:          A repl sistemo | shell | A repl semantika"
    echo ""
    log_info "Would launch workspace 4 (desk $((DESK_WS4 + 1))):"
    log_info "  basculer:        basculer-LLM (attach)  | shell"
    log_info "                   opencode-config-LLM (attach) | shell"
    log_info "                   opencode-agents (ls) | opencode-commands (ls)"
    log_info "  scratch:         nvim tmp.md | nvim lighterbird-1.md | nvim semantika-1.md"
    echo ""
    log_info "Would launch workspace 5 (desk $((DESK_WS5 + 1))):"
    log_info "  lighterbird:     gitmaster (mini+attach) | opencode (attach) | shell"
    log_info "  semantika:       gitmaster (mini+attach) | opencode (attach) | opencode (attach) | shell"
    log_info "  ronzzdoi:        gitmaster (mini+attach) | opencode (attach) | shell"
    echo ""
    log_info "Would launch workspace 12 (desk $((DESK_WS12 + 1))):"
    log_info "  fec-LLM:         opencode (attach) | shell | content"
    echo ""
    log_info "(All opencode tabs share one server at ${OPCODE_SERVE_URL})"
    exit 0
    ;;
  esac

  # ── Dependency checks ──────────────────────────────────────────────
  need_cmd "alacritty"
  need_cmd "zellij"
  need_cmd "opencode"
  need_cmd "curl"

  if ! $HAS_WMCTRL; then
    log_warn "wmctrl not found — virtual desktop switching disabled."
    log_warn "Install wmctrl for automatic workspace switching, or"
    log_warn "manually switch to the correct desktops when terminals open."
  fi

  # ── Directory checks ───────────────────────────────────────────────
  need_dir "$DIR_LIGHTER_CONFIG"
  need_dir "$DIR_LIGHTERBIRD"
  need_dir "$DIR_SEMANTIKA"
  need_dir "$DIR_BASCULER/opencode-config"
  need_dir "$DIR_SCRATCH"
  need_dir "$DIR_AUTISH"
  need_dir "$DIR_FEC"
  need_dir "$DIR_RONZZMARKMAP"
  need_dir "$DIR_RONZZDOI"

  # ── OpenCode server daemon (before terminals, must be ready first) ──
  echo ""
  launch_opencode_daemon || exit 1

  # ── Floorp session restore (before terminals take focus) ─────────────
  echo ""
  restore_floorp || true

  echo ""
  # Workspace configs: tab name|working directory (cwd)|init shell cmd|
  # ── Workspace 1: lighter-config + lighterbird + semantika ──────────
  log_info "=== Workspace 1 ==="
  launch_term "$DESK_WS1" "lighter-config" \
    "lighter-config|${DIR_LIGHTER_CONFIG}|nvim README.md" \
    "lighter-config-2|${DIR_LIGHTER_CONFIG}|" \
    "lighterbird-be|${DIR_LIGHTERBIRD}|git pull" \
    "fe|${DIR_LIGHTERBIRD}/web|" \
    "sh|${DIR_LIGHTERBIRD}|" \
    "semantika-be|${DIR_SEMANTIKA}|git pull" \
    "fe|${DIR_SEMANTIKA}/web|" \
    "sh|${DIR_SEMANTIKA}|"

  # ── Workspace 2: ronzz-markmap ──────────────────────────────────────
  log_info "=== Workspace 2 ==="
  launch_term "$DESK_WS2" "ronzz-markmap" \
    "shell|${DIR_RONZZMARKMAP}|" \
    "email-write|${DIR_RONZZMARKMAP}/email|ls" \
    "diary-write|${DIR_RONZZMARKMAP}/diary|ls"

  # ── Workspace 3: autish repl ───────────────────────────────────────
  log_info "=== Workspace 3 ==="
  launch_term "$DESK_WS3" "autish" \
    "A-sistemo-repl|${DIR_AUTISH}|${CMD_A_REPL_SISTEMO}" \
    "autish-sh|${DIR_AUTISH}|" \
    "A-semantika-repl|${DIR_AUTISH}|${CMD_A_REPL_SEMANTIKA}"

  # ── Workspace 4: opencode-config + scratch ─────────────────────────
  log_info "=== Workspace 4 ==="
  launch_term "$DESK_WS4" "basculer" \
    "basculer-LLM|${DIR_BASCULER}|${CMD_OPENCODE} --dir ${DIR_BASCULER}" \
    "sh|${DIR_BASCULER}|" \
    "opencode-config-LLM|${DIR_BASCULER}/opencode-config|${CMD_OPENCODE} --dir ${DIR_BASCULER}/opencode-config" \
    "sh|${DIR_BASCULER}/opencode-config|" \
    "opencode-agents|${DIR_BASCULER}/opencode-config/opencode/agents|ls" \
    "opencode-commands|${DIR_BASCULER}/opencode-config/opencode/commands|ls"

  launch_term "$DESK_WS4" "notes" \
    "tmp|${DIR_SCRATCH}|nvim ${DIR_SCRATCH}/tmp.md" \
    "lighterbird|${DIR_SCRATCH}|nvim ${DIR_SCRATCH}/lighterbird/lighterbird-1.md" \
    "semantika|${DIR_SCRATCH}|nvim ${DIR_SCRATCH}/semantika/semantika-1.md"

  # ── Workspace 5: lighterbird + semantika master ────────────────────
  log_info "=== Workspace 5 ==="
  launch_term "$DESK_WS5" "lbgm" \
    "gm|${DIR_LIGHTERBIRD}|${CMD_MASTER} --dir ${DIR_LIGHTERBIRD}" \
    "oc|${DIR_LIGHTERBIRD}|${CMD_OPENCODE} --dir ${DIR_LIGHTERBIRD}" \
    "sh|${DIR_LIGHTERBIRD}|"

  launch_term "$DESK_WS5" "smgm" \
    "gm|${DIR_SEMANTIKA}|${CMD_MASTER} --dir ${DIR_SEMANTIKA}" \
    "oc|${DIR_SEMANTIKA}|${CMD_OPENCODE} --dir ${DIR_SEMANTIKA}" \
    "builtin|${DIR_SEMANTIKA}|${CMD_OPENCODE} --dir ${DIR_SEMANTIKA}" \
    "sh|${DIR_SEMANTIKA}|"

  launch_term "$DESK_WS5" "rzdoi" \
    "gm|${DIR_RONZZDOI}|${CMD_MASTER} --dir ${DIR_RONZZDOI}" \
    "oc|${DIR_RONZZDOI}|${CMD_OPENCODE} --dir ${DIR_RONZZDOI}" \
    "sh|${DIR_RONZZDOI}|"

  # ── Workspace 12: france-en-chiffres ──────────────────────────────
  log_info "=== Workspace 12 ==="
  launch_term "$DESK_WS12" "fec" \
    "fec-LLM|${DIR_FEC}|${CMD_OPENCODE} --dir ${DIR_FEC}" \
    "sh|${DIR_FEC}|" \
    "content|${DIR_FEC}/src/content|"

  echo ""
  log_ok "All terminals launched. OpenCode server daemon still running (PID $(cat "$OPCODE_DAEMON_PID_FILE" 2>/dev/null || echo "unknown"))."
  log_info "Re-attach later:          zellij list-sessions  →  zellij attach <session-name>"
  echo ""
  log_info "New opencode session (any project):"
  log_info "  opencode attach ${OPCODE_SERVE_URL} --dir /path/to/project"
  log_info "  OPENCODE_CONFIG_CONTENT='{\"default_agent\":\"gitmaster\"}' opencode attach ${OPCODE_SERVE_URL} --mini --dir /path/to/project"
  echo ""
  log_info "Kill daemon:      kill \$(cat ${OPCODE_DAEMON_PID_FILE})"
  log_info "Daemon log:       ${OPCODE_DAEMON_LOG}"
}

main "$@"
