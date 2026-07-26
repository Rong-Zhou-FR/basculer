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
#   WS 3 (desk 2) — 1 terminal, 3 tabs + desktop-plus GUI:
#     autish:           A repl sistemo | shell | A repl semantika
#   WS 4 (desk 3) — 2 terminals:
#     basculer:         basculer-LLM (opencode) | shell | opencode-config-LLM (opencode)
#                       | shell | opencode-agents (ls) | opencode-commands (ls)
#     scratch:          nvim tmp.md | nvim lighterbird-1.md | nvim semantika-1.md
#   WS 5 (desk 4) — 4 terminals:
#     lighterbird:      gitmaster | opencode | shell
#     semantika:        gitmaster | opencode | opencode (builtin) | shell
#     ronzzdoi:         gitmaster | opencode | shell
#     classroomioplus:  gitmaster | opencode | shell
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
DIR_CLASSROOMIOPLUS="$HOME/kodo/classroomioplus"

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
FLOORP_WAIT=10
# Seconds to wait for opencode serve to bind its port after launch.
OPCODE_DAEMON_TIMEOUT=30

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

# Dry-run mode flag — set via --dry-run flag; functions check this to skip
# side-effects and print their launch plan instead.
DRY_RUN=false

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
    while ((settle < 20)); do
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

  if $DRY_RUN; then
    local desk_num=$((desk_index + 1))
    log_info "Terminal «${label}» on desk ${desk_num} — ${#tab_specs[@]} tabs:"
    local tab_name workdir cmd
    for spec in "${tab_specs[@]}"; do
      IFS='|' read -r tab_name workdir cmd <<<"$spec"
      log_info "  Tab  «${tab_name}»  @ ${workdir}  ${cmd:-(shell)}"
    done
    return 0
  fi

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
      break # stale session fully removed
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
  # Note: $! captures the setsid-wrapper PID (which exits immediately), not the
  # alacritty grandchild — so we don't check it. Startup failure is detected
  # reliably in Steps 5–6 (list-sessions + query-tab-names polling).
  setsid alacritty -e zellij --session "$session_name" >/dev/null 2>/tmp/lighter-dev-alacritty-${label}.log &

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

  local t_elapsed=$(($(date +%s) - t_start))
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
      break # session responded with tab names
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
        --name "$tab_name" --cwd "$workdir" &&
        t_created=$((t_created + 1)) || t_failed=$((t_failed + 1))
    else
      run_captured "new-tab ${tab_name}" \
        zellij --session "$session_name" action new-tab \
        --name "$tab_name" --cwd "$workdir" \
        -- bash -c "$cmd; exec bash" &&
        t_created=$((t_created + 1)) || t_failed=$((t_failed + 1))
    fi
  done
  if ((t_failed > 0)); then
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
  if ((actual_count < expected_count)); then
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
    if ((missing_count > 0)); then
      log_info "Retried ${missing_count} missing tab(s) for «${session_name}»."
      # Second-verification pass
      local verify_count
      verify_count=$(zellij --session "$session_name" action query-tab-names 2>/dev/null | grep -c . || true)
      if ((verify_count < expected_count)); then
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
  if $DRY_RUN; then
    log_info "Floorp: would restore if not running (wait ${FLOORP_WAIT}s for windows)"
    return 0
  fi

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
  # Note: $! captures the setsid-wrapper PID (which exits immediately), not the
  # floorp grandchild — so we use pgrep to find the real floorp PID.
  setsid "$FLOORP_BIN" "${launch_args[@]}" >/dev/null 2>/tmp/lighter-dev-floorp.log &

  # Quick check: did floorp start? Use pgrep (not $!) because setsid
  # creates a grandchild process.
  sleep 0.5
  local floorp_pid_new
  floorp_pid_new="$(pgrep -x -u "$(id -u)" "$(basename "${FLOORP_BIN}")" 2>/dev/null || true)"
  if [[ -z "$floorp_pid_new" ]]; then
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

# Preemptive cleanup: kill any existing opencode server on our port.
# Called unconditionally in main() so stale daemons are always freed,
# even when no workspace item needs opencode this session.
_cleanup_opencode_daemon() {
  if $DRY_RUN; then
    log_info "OpenCode: would stop any existing server on port ${OPCODE_SERVE_PORT} (preemptive cleanup)"
    return 0
  fi

  local port_pid
  port_pid=$(ss -tlnp 2>/dev/null |
    grep -F ":${OPCODE_SERVE_PORT}" |
    grep -o 'pid=[0-9][0-9]*' |
    grep -o '[0-9][0-9]*' ||
    true)
  if [[ -z "$port_pid" ]]; then
    return 0
  fi

  if ps -p "$port_pid" -o comm= 2>/dev/null | grep -qxF 'opencode'; then
    log_info "Stopping existing OpenCode server (PID $port_pid) …"
    # timeout: systemctl --user stop can hang if the unit ignores SIGTERM.
    timeout 5 systemctl --user stop opencode-serve 2>/dev/null || kill "$port_pid" 2>/dev/null || true
    local wait_release=10
    while ((wait_release > 0)); do
      port_pid=$(ss -tlnp 2>/dev/null |
        grep -F ":${OPCODE_SERVE_PORT}" |
        grep -o 'pid=[0-9][0-9]*' |
        grep -o '[0-9][0-9]*' ||
        true)
      [[ -z "$port_pid" ]] && break
      sleep 1
      ((wait_release--)) || true
    done
    if [[ -n "$port_pid" ]]; then
      log_warn "Port ${OPCODE_SERVE_PORT} still held after 10s — forcing…"
      kill -9 "$port_pid" 2>/dev/null || true
      sleep 1
    fi
    rm -f "$OPCODE_DAEMON_PID_FILE"
  else
    log_warn "Port ${OPCODE_SERVE_PORT} is held by non-opencode process"
    log_warn "  (PID $port_pid: $(ps -p "$port_pid" -o comm= 2>/dev/null || echo 'unknown'))"
    # Non-blocking: warn only — start will fail later if we need the port.
  fi
}

# Start the shared `opencode serve` daemon.  Port should be clean after
# _cleanup_opencode_daemon ran, but we verify defensively.
launch_opencode_daemon() {
  if $DRY_RUN; then
    log_info "OpenCode: would start server on port ${OPCODE_SERVE_PORT} via systemd-run"
    return 0
  fi

  need_cmd "opencode"

  # Verify port is free (cleanup should have handled it, but defend against
  # racy re-occupation or a non-opencode holder).
  local port_pid
  port_pid=$(ss -tlnp 2>/dev/null |
    grep -F ":${OPCODE_SERVE_PORT}" |
    grep -o 'pid=[0-9][0-9]*' |
    grep -o '[0-9][0-9]*' ||
    true)
  if [[ -n "$port_pid" ]]; then
    if ps -p "$port_pid" -o comm= 2>/dev/null | grep -qxF 'opencode'; then
      log_warn "Port ${OPCODE_SERVE_PORT} still occupied by opencode (PID $port_pid) — force killing"
      kill -9 "$port_pid" 2>/dev/null || true
      sleep 1
      rm -f "$OPCODE_DAEMON_PID_FILE"
    else
      log_err "Port ${OPCODE_SERVE_PORT} is held by non-opencode process (PID $port_pid)"
      log_err "  Cannot start opencode daemon."
      return 1
    fi
  fi

  # ── Start daemon ────────────────────────────────────────────────────
  log_info "Starting OpenCode server daemon on port ${OPCODE_SERVE_PORT} …"
  systemd-run --user --unit=opencode-serve --collect \
    --property="StandardOutput=file:${OPCODE_DAEMON_LOG}" \
    --property="StandardError=file:${OPCODE_DAEMON_LOG}" \
    --same-dir \
    opencode serve --port "$OPCODE_SERVE_PORT"

  # Poll ss until the port is bound.
  local timeout=$OPCODE_DAEMON_TIMEOUT
  while ((timeout > 0)); do
    port_pid=$(ss -tlnp 2>/dev/null |
      grep -F ":${OPCODE_SERVE_PORT}" |
      grep -o 'pid=[0-9][0-9]*' |
      grep -o '[0-9][0-9]*' ||
      true)
    if [[ -n "$port_pid" ]]; then
      if ps -p "$port_pid" -o comm= 2>/dev/null | grep -qxF 'opencode'; then
        echo "$port_pid" >"$OPCODE_DAEMON_PID_FILE"
        log_ok "OpenCode server daemon ready (PID $port_pid)"
        return 0
      fi
      log_err "Port ${OPCODE_SERVE_PORT} claimed by non-opencode process (PID $port_pid)"
      log_err "  Check: ${OPCODE_DAEMON_LOG}"
      return 1
    fi
    sleep 1
    ((timeout--)) || true
  done

  log_err "OpenCode server daemon did not bind port ${OPCODE_SERVE_PORT} within ${OPCODE_DAEMON_TIMEOUT}s"
  log_err "  Check: ${OPCODE_DAEMON_LOG}"
  return 1
}

# ── Workspace item registry ──────────────────────────────────────────
# Add new items with _register_item, then implement _run_<id>().
# Array order = menu order.  Metadata is kept in sync automatically.
# Numbering: item N gets menu number N+1.  New items appended to the
# end get the next number.  Inserting mid-array renumbers everything
# after the insertion point — update menu references accordingly.

declare -a _WS_IDS=()          # item IDs (parallel arrays, same index)
declare -a _WS_LABELS=()       # display labels
declare -a _WS_NEEDS_OPENCODE=()  # "true" / "false"

_register_item() {
  _WS_IDS+=("$1")
  _WS_LABELS+=("$2")
  _WS_NEEDS_OPENCODE+=("$3")
}

# ── Registrations ───────────────────────────────────────────────────
# Usage: _register_item "<id>" "<menu label>" <needs_opencode>
_register_item "ws_floorp"            "pre — Floorp browser (session restore)"         false
_register_item "ws1_config"           "WS1 — lighter-config (8 tabs)"                    false
_register_item "ws2_markmap"          "WS2 — ronzz-markmap (3 tabs)"                     false
_register_item "ws3_autish"           "WS3 — autish repl (3 tabs)"                       false
_register_item "ws3_desktop_plus"     "WS3 — desktop-plus (GUI)"                         false
_register_item "ws4_basculer"         "WS4 — basculer (6 tabs)"                           true
_register_item "ws4_notes"            "WS4 — notes/scratch (3 tabs)"                     false
_register_item "ws5_lbgm"             "WS5 — lighterbird (gm + oc + shell)"               true
_register_item "ws5_smgm"             "WS5 — semantika (gm + 2x oc + shell)"              true
_register_item "ws5_rzdoi"            "WS5 — ronzzdoi (gm + oc + shell)"                  true
_register_item "ws5_classroomioplus"  "WS5 — classroomioplus (gm + oc + shell)"           true
_register_item "ws12_fec"             "WS12 — france-en-chiffres (3 tabs)"                true

SELECTED_ITEMS="__ALL__"

# Returns the display label for a workspace item ID.
_ws_label() {
  local id="$1" i
  for ((i=0; i<${#_WS_IDS[@]}; i++)); do
    [[ "${_WS_IDS[i]}" == "$id" ]] && { echo "${_WS_LABELS[i]}"; return 0; }
  done
  echo "UNKNOWN:${id}"
  return 1
}

# Show the interactive selection menu.  User enters space-separated numbers
# of items to START.  Empty input (just Enter) launches everything.
_prompt_selection() {
  echo ""
  echo "================================================================="
  echo "  Lighter Development Workspace — interactive launch"
  echo "================================================================="
  echo ""
  local i label
  for ((i=0; i<${#_WS_IDS[@]}; i++)); do
    label="$(_ws_label "${_WS_IDS[i]}")"
    printf "  %2d.  %s\n" $((i+1)) "$label"
  done
  echo ""
  echo "  Enter space-separated numbers to launch ONLY those items."
  read -r -p "  Press Enter to launch ALL: " user_input
  echo ""
  if [[ -z "$user_input" ]]; then
    SELECTED_ITEMS="__ALL__"
  else
    SELECTED_ITEMS="$user_input"
  fi
}

# Check if a given item number (1-indexed) was selected by the user.
should_launch() {
  local num="$1"
  [[ "$SELECTED_ITEMS" == "__ALL__" ]] && return 0
  local n
  for n in $SELECTED_ITEMS; do
    [[ "$n" == "$num" ]] && return 0
  done
  return 1
}

# Dispatch to _run_<id>() by dynamic function name.
# No case-statement to maintain — implement _run_<id>() and it works.
_run_workspace_item() {
  local id="$1"
  if declare -F "_run_${id}" &>/dev/null; then
    "_run_${id}"
  else
    log_err "No _run_${id} function defined for workspace item «${id}»"
  fi
}

# ── Workspace item implementations ──────────────────────────────────
# Each _run_<id> function contains the original launch_term / GUI code.

_run_ws1_config() {
  log_info "=== Workspace 1 — lighter-config ==="
  launch_term "$DESK_WS1" "lighter-config" \
    "lighter-config|${DIR_LIGHTER_CONFIG}|nvim README.md" \
    "lighter-config-2|${DIR_LIGHTER_CONFIG}|" \
    "lighterbird-be|${DIR_LIGHTERBIRD}|git pull" \
    "fe|${DIR_LIGHTERBIRD}/web|" \
    "sh|${DIR_LIGHTERBIRD}|" \
    "semantika-be|${DIR_SEMANTIKA}|git pull" \
    "fe|${DIR_SEMANTIKA}/web|" \
    "sh|${DIR_SEMANTIKA}|"
}

_run_ws2_markmap() {
  log_info "=== Workspace 2 — ronzz-markmap ==="
  launch_term "$DESK_WS2" "ronzz-markmap" \
    "shell|${DIR_RONZZMARKMAP}|" \
    "email-write|${DIR_RONZZMARKMAP}/email|ls" \
    "diary-write|${DIR_RONZZMARKMAP}/diary|ls"
}

_run_ws3_autish() {
  log_info "=== Workspace 3 — autish repl ==="
  launch_term "$DESK_WS3" "autish" \
    "A-sistemo-repl|${DIR_AUTISH}|${CMD_A_REPL_SISTEMO}" \
    "autish-sh|${DIR_AUTISH}|" \
    "A-semantika-repl|${DIR_AUTISH}|${CMD_A_REPL_SEMANTIKA}"
}

_run_ws3_desktop_plus() {
  if $DRY_RUN; then
    log_info "GUI: desktop-plus (detached)"
  else
    log_info "Launching desktop-plus GUI …"
    setsid desktop-plus >/dev/null 2>&1 &
  fi
}

_run_ws4_basculer() {
  log_info "=== Workspace 4 — basculer ==="
  launch_term "$DESK_WS4" "basculer" \
    "basculer-LLM|${DIR_BASCULER}|${CMD_OPENCODE} --dir ${DIR_BASCULER}" \
    "sh|${DIR_BASCULER}|" \
    "opencode-config-LLM|${DIR_BASCULER}/opencode-config|${CMD_OPENCODE} --dir ${DIR_BASCULER}/opencode-config" \
    "sh|${DIR_BASCULER}/opencode-config|" \
    "opencode-agents|${DIR_BASCULER}/opencode-config/opencode/agents|ls" \
    "opencode-commands|${DIR_BASCULER}/opencode-config/opencode/commands|ls"
}

_run_ws4_notes() {
  log_info "=== Workspace 4 — scratch notes ==="
  launch_term "$DESK_WS4" "notes" \
    "tmp|${DIR_SCRATCH}|nvim ${DIR_SCRATCH}/tmp.md" \
    "lighterbird|${DIR_SCRATCH}|nvim ${DIR_SCRATCH}/lighterbird/lighterbird-1.md" \
    "semantika|${DIR_SCRATCH}|nvim ${DIR_SCRATCH}/semantika/semantika-1.md"
}

_run_ws5_lbgm() {
  log_info "=== Workspace 5 — lighterbird ==="
  launch_term "$DESK_WS5" "lbgm" \
    "gm|${DIR_LIGHTERBIRD}|${CMD_MASTER} --dir ${DIR_LIGHTERBIRD}" \
    "oc|${DIR_LIGHTERBIRD}|${CMD_OPENCODE} --dir ${DIR_LIGHTERBIRD}" \
    "sh|${DIR_LIGHTERBIRD}|"
}

_run_ws5_smgm() {
  log_info "=== Workspace 5 — semantika ==="
  launch_term "$DESK_WS5" "smgm" \
    "gm|${DIR_SEMANTIKA}|${CMD_MASTER} --dir ${DIR_SEMANTIKA}" \
    "oc|${DIR_SEMANTIKA}|${CMD_OPENCODE} --dir ${DIR_SEMANTIKA}" \
    "builtin|${DIR_SEMANTIKA}|${CMD_OPENCODE} --dir ${DIR_SEMANTIKA}" \
    "sh|${DIR_SEMANTIKA}|"
}

_run_ws5_rzdoi() {
  log_info "=== Workspace 5 — ronzzdoi ==="
  launch_term "$DESK_WS5" "rzdoi" \
    "gm|${DIR_RONZZDOI}|${CMD_MASTER} --dir ${DIR_RONZZDOI}" \
    "oc|${DIR_RONZZDOI}|${CMD_OPENCODE} --dir ${DIR_RONZZDOI}" \
    "sh|${DIR_RONZZDOI}|"
}

_run_ws5_classroomioplus() {
  log_info "=== Workspace 5 — classroomioplus ==="
  launch_term "$DESK_WS5" "classroomioplus" \
    "gm|${DIR_CLASSROOMIOPLUS}|${CMD_MASTER} --dir ${DIR_CLASSROOMIOPLUS}" \
    "oc|${DIR_CLASSROOMIOPLUS}|${CMD_OPENCODE} --dir ${DIR_CLASSROOMIOPLUS}" \
    "sh|${DIR_CLASSROOMIOPLUS}|"
}

_run_ws12_fec() {
  log_info "=== Workspace 12 — france-en-chiffres ==="
  launch_term "$DESK_WS12" "fec" \
    "fec-LLM|${DIR_FEC}|${CMD_OPENCODE} --dir ${DIR_FEC}" \
    "sh|${DIR_FEC}|" \
    "content|${DIR_FEC}/src/content|"
}

_run_ws_floorp() {
  restore_floorp
}

# ── Main ───────────────────────────────────────────────────────────────────

main() {
  case "${1:-}" in
  --help | -h)
    sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
    exit 0
    ;;
  --dry-run | --dry)
    DRY_RUN=true
    log_info "Dry run — validating configuration without launching anything."
    echo ""
    ;;
  esac

  # ── Dependency checks ──────────────────────────────────────────────
  # NOTE: opencode is checked inside launch_opencode_daemon — it's only
  # required when an opencode workspace item is selected.
  need_cmd "alacritty"
  need_cmd "zellij"
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
  need_dir "$DIR_CLASSROOMIOPLUS"

  # ── Interactive selection ─────────────────────────────────────────
  # Must happen BEFORE daemon/floorp so we know what to launch.
  # In dry-run mode skip the prompt and show everything.
  if ! $DRY_RUN; then
    _prompt_selection
  fi

  # ── Preemptive cleanup: kill any stale opencode daemon ─────────────
  # Always runs (even when no opencode items are selected) so stale
  # ~600MB servers are freed before terminals take focus.
  echo ""
  _cleanup_opencode_daemon

  # ── Floorp session restore (before terminals take focus) ─────────────
  # Floorp is item at index 0 (menu number 1).
  echo ""
  if $DRY_RUN || should_launch 1; then
    restore_floorp || true
  else
    log_info "Skipping Floorp restore (not selected)"
  fi

  # ── OpenCode server daemon (only if needed) ───────────────────────
  # Check whether any selected workspace item needs opencode.  If none
  # do, skip the daemon entirely (saves ~600 MB + startup time).
  local _needs_opencode=false
  local _oc_idx
  for ((_oc_idx=0; _oc_idx<${#_WS_IDS[@]}; _oc_idx++)); do
    if $DRY_RUN || should_launch $((_oc_idx + 1)); then
      if [[ "${_WS_NEEDS_OPENCODE[_oc_idx]}" == "true" ]]; then
        _needs_opencode=true
        break
      fi
    fi
  done
  if $_needs_opencode; then
    echo ""
    launch_opencode_daemon || exit 1
  elif $DRY_RUN; then
    echo ""
    log_info "OpenCode daemon not needed (no opencode items selected)"
  fi

  echo ""

  # ── Launch selected workspace items ──────────────────────────────
  # Floorp (index 0) was handled early; skip it in the loop.
  local _item_idx _item_id
  for ((_item_idx=1; _item_idx<${#_WS_IDS[@]}; _item_idx++)); do
    _item_id="${_WS_IDS[_item_idx]}"
    if $DRY_RUN || should_launch $((_item_idx + 1)); then
      _run_workspace_item "$_item_id"
    else
      log_info "Skipping «${_item_id}» (not selected)"
    fi
  done

  echo ""
  if $DRY_RUN; then
    log_ok "Dry run complete — no commands executed, no terminals launched."
    log_info "Run without --dry-run to launch the workspace."
  else
    if $_needs_opencode; then
      log_ok "All terminals launched. OpenCode server daemon still running (PID $(cat "$OPCODE_DAEMON_PID_FILE" 2>/dev/null || echo "unknown"))."
      log_info "Re-attach later:          zellij list-sessions  →  zellij attach <session-name>"
      echo ""
      log_info "New opencode session (any project):"
      log_info "  opencode attach ${OPCODE_SERVE_URL} --dir /path/to/project"
      log_info "  OPENCODE_CONFIG_CONTENT='{\"default_agent\":\"gitmaster\"}' opencode attach ${OPCODE_SERVE_URL} --mini --dir /path/to/project"
      echo ""
      log_info "Kill daemon:      systemctl --user stop opencode-serve  (or: kill \$(cat ${OPCODE_DAEMON_PID_FILE}))"
      log_info "Restart daemon:   Re-run this script (kills + restarts)"
      log_info "Daemon log:       ${OPCODE_DAEMON_LOG}"
    else
      log_ok "All selected items launched (opencode daemon was not started)."
    fi
  fi
}

main "$@"
