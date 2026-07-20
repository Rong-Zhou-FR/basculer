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

# ── Custom commands (must be on PATH or defined in bashrc) ─────────────────
CMD_MASTER="opencode --agent gitmaster"
CMD_OPENCODE="opencode"
CMD_A_REPL_SISTEMO="A repl sistemo"
CMD_A_REPL_SEMANTIKA="A repl semantika"

# ── Virtual desktop mapping (1-indexed workspace → 0-indexed wmctrl) ──────
# Change the list below if your desktop manager uses a different numbering.
for ws in 1 2 3 4 5 12; do
  declare "DESK_WS${ws}=$((ws-1))"
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
  fi
}

# Launch a development workspace terminal.
#
# Approach:
#   1. Delete any stale session with the target name (clean slate)
#   2. Switch to target virtual desktop
#   3. Launch bare Zellij in Alacritty — default config loads, full UX frame
#   4. Wait for session daemon to appear (polling, with timeout)
#   5. For each tab spec, create a new tab via `zellij action new-tab --cwd`
#   6. Close the auto-created default tab (best-effort)
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

  log_info "Launching «${label}» on desktop $((desk_index + 1)) …"

  # Step 1: Delete stale session (clean slate)
  run_captured "delete-session ${session_name}" \
    zellij delete-session --force "$session_name" || true

  # Step 2: Switch to target virtual desktop
  switch_desktop "$desk_index"

  # Step 3: Launch bare Zellij via Alacritty — full UX frame from default config
  alacritty -e zellij --session "$session_name" >/dev/null 2>/tmp/lighter-dev-alacritty-${label}.log &
  local alacritty_pid=$!

  # Quick check: did alacritty start?
  sleep 0.3
  if ! kill -0 "$alacritty_pid" 2>/dev/null; then
    log_warn "Alacritty exited immediately for «${label}»"
    log_warn "  Check: $(cat /tmp/lighter-dev-alacritty-${label}.log 2>/dev/null || echo "no log")"
    rm -f /tmp/lighter-dev-alacritty-${label}.log
    return 0
  fi

  # Step 4: Wait for the session daemon to be ready
  local timeout=$SESSION_READY_TIMEOUT
  while ((timeout > 0)); do
    if zellij list-sessions 2>/dev/null |
      sed 's/\x1b\[[0-9;]*m//g' |
      awk '{print $1}' |
      grep -qxF "$session_name"; then
      break
    fi
    sleep 1
    ((timeout--))
  done

  if ((timeout == 0)); then
    log_warn "Session «${session_name}» not ready within ${SESSION_READY_TIMEOUT}s"
    log_warn "  Alacritty log: $(cat /tmp/lighter-dev-alacritty-${label}.log 2>/dev/null || echo "empty")"
    rm -f /tmp/lighter-dev-alacritty-${label}.log
    return 0
  fi
  rm -f /tmp/lighter-dev-alacritty-${label}.log

  sleep 0.5

  # Step 5: Create each tab via `zellij action new-tab`
  # Each new tab inherits the session's UX frame (tab-bar, status-bar).
  # Shell-only tabs: just set name and cwd.
  # Command tabs: wrap in `bash -c "cmd; exec bash"` to keep pane open.
  local tab_name workdir cmd
  for spec in "${tab_specs[@]}"; do
    IFS='|' read -r tab_name workdir cmd <<<"$spec"
    if [[ -z "$cmd" ]]; then
      run_captured "new-tab ${tab_name}" \
        zellij --session "$session_name" action new-tab \
        --name "$tab_name" --cwd "$workdir" || true
    else
      run_captured "new-tab ${tab_name}" \
        zellij --session "$session_name" action new-tab \
        --name "$tab_name" --cwd "$workdir" \
        -- bash -c "$cmd; exec bash" || true
    fi
  done

  # Step 6: Close the auto-created default tab (best-effort)
  run_captured "go-to-tab 0" \
    zellij --session "$session_name" action go-to-tab 0 || true
  run_captured "close-tab" \
    zellij --session "$session_name" action close-tab || true
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
    log_info "  basculer:        basculer-LLM (opencode) | shell | opencode-config-LLM (opencode)"
    log_info "                   | shell | opencode-agents (ls) | opencode-commands (ls)"
    log_info "  scratch:         nvim tmp.md | nvim lighterbird-1.md | nvim semantika-1.md"
    echo ""
    log_info "Would launch workspace 5 (desk $((DESK_WS5 + 1))):"
    log_info "  lighterbird:     gitmaster | opencode | shell"
    log_info "  semantika:       gitmaster | opencode | opencode (builtin) | shell"
    log_info "  ronzzdoi:        gitmaster | opencode | shell"
    echo ""
    log_info "Would launch workspace 12 (desk $((DESK_WS12 + 1))):"
    log_info "  fec-LLM:         opencode | shell | content"
    exit 0
    ;;
  esac

  # ── Dependency checks ──────────────────────────────────────────────
  need_cmd "alacritty"
  need_cmd "zellij"

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

  # ── Floorp session restore (before terminals take focus) ─────────────
  echo ""
  restore_floorp

  echo ""
  # Workspace configs: tab name|working directory (cwd)|init shell cmd|
  # ── Workspace 1: lighter-config + lighterbird + semantika ──────────
  log_info "=== Workspace 1 ==="
  launch_term "$DESK_WS1" "testing" \
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
    "basculer-LLM|${DIR_BASCULER}|${CMD_OPENCODE}" \
    "sh|${DIR_BASCULER}|" \
    "opencode-config-LLM|${DIR_BASCULER}/opencode-config|${CMD_OPENCODE}" \
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
    "gm|${DIR_LIGHTERBIRD}|${CMD_MASTER}" \
    "oc|${DIR_LIGHTERBIRD}|${CMD_OPENCODE}" \
    "sh|${DIR_LIGHTERBIRD}|"

  launch_term "$DESK_WS5" "smgm" \
    "gm|${DIR_SEMANTIKA}|${CMD_MASTER}" \
    "oc|${DIR_SEMANTIKA}|${CMD_OPENCODE}" \
    "builtin|${DIR_SEMANTIKA}|${CMD_OPENCODE}" \
    "sh|${DIR_SEMANTIKA}|"

  launch_term "$DESK_WS5" "rzdoi" \
    "gm|${DIR_RONZZDOI}|${CMD_MASTER}" \
    "oc|${DIR_RONZZDOI}|${CMD_OPENCODE}" \
    "sh|${DIR_RONZZDOI}|"

  # ── Workspace 12: france-en-chiffres ──────────────────────────────
  log_info "=== Workspace 12 ==="
  launch_term "$DESK_WS12" "fec" \
    "fec-LLM|${DIR_FEC}|${CMD_OPENCODE}" \
    "sh|${DIR_FEC}|" \
    "content|${DIR_FEC}/src/content|"

  echo ""
  log_ok "All terminals launched. Zellij sessions are running."
  log_info "Re-attach later:  zellij list-sessions  →  zellij attach <session-name>"
}

main "$@"
