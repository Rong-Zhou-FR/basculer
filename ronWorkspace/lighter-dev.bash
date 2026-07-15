#!/usr/bin/env bash
#
# lighter-dev.bash — Launch the lighter-system development workspace
#
# Opens Alacritty+Zellij terminals across multiple Linux virtual desktops,
# each pre-configured with project directories and startup commands.
# Designed for the lighter-system development workflow.
#
# Workspace layout:
#   WS 1 (desk 0) — 1 terminal, 6 tabs:
#     lighter-config:   nvim README.md | shell
#     lighterbird:      git pull       | shell
#     semantika:        git pull       | shell
#   WS 3 (desk 2) — 1 terminal, 3 tabs:
#     autish:           A repl sistemo | shell | A repl semantika
#   WS 4 (desk 3) — 2 terminals:
#     opencode-config:  opencode       | shell
#     scratch:          nvim tmp.md | nvim lighterbird-1.md | nvim semantika-1.md
#   WS 5 (desk 4) — 2 terminals:
#     lighterbird:      omaster | shell
#     semantika:        omaster | shell
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
DIR_BASCULER_OPENCODE="$HOME/kodo/basculer/opencode-config"
DIR_SCRATCH="$HOME/scratch"
DIR_AUTISH="$HOME/kodo/autish"

# ── Custom commands (must be on PATH or defined in bashrc) ─────────────────
CMD_MASTER="opencode --agent gitmaster"
CMD_OPENCODE="opencode"
CMD_A_REPL_SISTEMO="A repl sistemo"
CMD_A_REPL_SEMANTIKA="A repl semantika"

# ── Virtual desktop mapping (1-indexed workspace → 0-indexed wmctrl) ──────
# Change these if your desktop manager uses a different numbering.
DESK_WS1=0 # Workspace 1
DESK_WS3=2 # Workspace 3
DESK_WS4=3 # Workspace 4
DESK_WS5=4 # Workspace 5

# ── Floorp browser ─────────────────────────────────────────────────────────
# If floorp is not running when the workspace launches, start it so its
# built-in session restore reopens previous windows on their desktops.
# The script launches floorp before creating terminals so windows settle
# before Alacritty windows take focus.
FLOORP_BIN="${FLOORP_BIN:-floorp}"
FLOORP_PROFILE=""   # empty = default profile
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
  zellij delete-session --force "$session_name" 2>/dev/null || true

  # Step 2: Switch to target virtual desktop
  switch_desktop "$desk_index"

  # Step 3: Launch bare Zellij via Alacritty — full UX frame from default config
  alacritty -e zellij --session "$session_name" &>/dev/null &

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
    return 0
  fi

  sleep 0.5

  # Step 5: Create each tab via `zellij action new-tab`
  # Each new tab inherits the session's UX frame (tab-bar, status-bar).
  # Shell-only tabs: just set name and cwd.
  # Command tabs: wrap in `bash -c "cmd; exec bash"` to keep pane open.
  local tab_name workdir cmd
  for spec in "${tab_specs[@]}"; do
    IFS='|' read -r tab_name workdir cmd <<<"$spec"
    if [[ -z "$cmd" ]]; then
      zellij --session "$session_name" action new-tab \
        --name "$tab_name" --cwd "$workdir" &>/dev/null || true
    else
      zellij --session "$session_name" action new-tab \
        --name "$tab_name" --cwd "$workdir" \
        -- bash -c "$cmd; exec bash" &>/dev/null || true
    fi
  done

  # Step 6: Close the auto-created default tab (best-effort)
  zellij --session "$session_name" action go-to-tab 0 &>/dev/null || true
  zellij --session "$session_name" action close-tab &>/dev/null || true
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
  setsid "$FLOORP_BIN" "${launch_args[@]}" &>/dev/null &

  log_info "Waiting ${FLOORP_WAIT}s for Floorp windows to appear …"
  sleep "$FLOORP_WAIT"

  # ── Count restored windows ────────────────────────────────────────────────
  local win_count
  win_count="$(wmctrl -l 2>/dev/null | grep -ic "ablaze floorp\|floorp\|mozilla firefox" || true)"
  if [[ "$win_count" -gt 0 ]]; then
    log_ok "Floorp restored — $win_count window(s) detected"
  else
    log_warn "Floorp launched but no windows detected via wmctrl"
    log_warn "(Session restore may still be pending or wmctrl not available)"
  fi
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
    log_info "Would launch workspace 3 (desk $((DESK_WS3 + 1))):"
    log_info "  autish:          A repl sistemo | shell | A repl semantika"
    echo ""
    log_info "Would launch workspace 4 (desk $((DESK_WS4 + 1))):"
    log_info "  opencode-config: opencode | shell"
    log_info "  scratch:         nvim tmp.md | nvim lighterbird-1.md | nvim semantika-1.md"
    echo ""
    log_info "Would launch workspace 5 (desk $((DESK_WS5 + 1))):"
    log_info "  lighterbird:     omaster | shell"
    log_info "  semantika:       omaster | shell"
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
  need_dir "$DIR_BASCULER_OPENCODE"
  need_dir "$DIR_SCRATCH"
  need_dir "$DIR_AUTISH"

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
    "lighterbird-fe|${DIR_LIGHTERBIRD}|" \
    "semantika-be|${DIR_SEMANTIKA}|git pull" \
    "semantika-fe|${DIR_SEMANTIKA}|"

  # ── Workspace 3: autish repl ───────────────────────────────────────
  log_info "=== Workspace 3 ==="
  launch_term "$DESK_WS3" "autish" \
    "A-sistemo-repl|${DIR_AUTISH}|${CMD_A_REPL_SISTEMO}" \
    "autish-shell|${DIR_AUTISH}|" \
    "A-semantika-repl|${DIR_AUTISH}|${CMD_A_REPL_SEMANTIKA}"

  # ── Workspace 4: opencode-config + scratch ─────────────────────────
  log_info "=== Workspace 4 ==="
  launch_term "$DESK_WS4" "basculer" \
    "basculer-opencode|${DIR_BASCULER_OPENCODE}|${CMD_OPENCODE}" \
    "shell|${DIR_BASCULER_OPENCODE}|"

  launch_term "$DESK_WS4" "scratch" \
    "tmp-notes|${DIR_SCRATCH}|nvim ./tmp.md" \
    "lighterbird-notes|${DIR_SCRATCH}|nvim ./lighterbird/lighterbird-1.md" \
    "semantika-notes|${DIR_SCRATCH}|nvim ./semantika/semantika-1.md"

  # ── Workspace 5: lighterbird + semantika master ────────────────────
  log_info "=== Workspace 5 ==="
  launch_term "$DESK_WS5" "lighterbird-gitmaster" \
    "lighterbird-gitmaster|${DIR_LIGHTERBIRD}|${CMD_MASTER}" \
    "shell|${DIR_LIGHTERBIRD}|"

  launch_term "$DESK_WS5" "semantika-gitmaster" \
    "semantika-gitmaster|${DIR_SEMANTIKA}|${CMD_MASTER}" \
    "shell|${DIR_SEMANTIKA}|"

  echo ""
  log_ok "All terminals launched. Zellij sessions are running."
  log_info "Re-attach later:  zellij list-sessions  →  zellij attach <session-name>"
}

main "$@"
