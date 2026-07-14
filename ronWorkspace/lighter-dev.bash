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
#     lighterbird:      omaster
#     semantika:        omaster
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
DESK_WS1=0    # Workspace 1
DESK_WS3=2    # Workspace 3
DESK_WS4=3    # Workspace 4
DESK_WS5=4    # Workspace 5

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

# Temp directory for generated layout files.
LAYOUT_DIR="/tmp/lighter-dev-layouts"

# Seconds to wait for a Zellij session daemon to start after launch.
SESSION_READY_TIMEOUT=15

# ── Helpers ────────────────────────────────────────────────────────────────

log_info() { printf '\e[34m[INFO]\e[0m  %s\n' "$*"; }
log_ok()   { printf '\e[32m[OK]\e[0m    %s\n' "$*"; }
log_warn() { printf '\e[33m[WARN]\e[0m  %s\n' "$*"; }
log_err()  { printf '\e[31m[ERROR]\e[0m %s\n' "$*" >&2; }

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

# ── Layout generation ──────────────────────────────────────────────────────

# Write a Zellij KDL layout file for a set of tabs.
#
# Uses Zellij's native `cwd` attribute for working directories (no bash-cd trickery).
# For command tabs, wraps in `bash -c "cmd; exec bash"` so the pane stays open
# after the command finishes.
#
# Usage: gen_layout <filepath> <tab-spec>...
# Each <tab-spec> is "tab_name|workdir|command"
# If command is empty, opens a shell in workdir.
gen_layout() {
    local filepath="$1"
    shift

    printf 'layout {\n' > "$filepath"

    local tab_index=0
    local tab_name workdir cmd escaped_name escaped_workdir escaped_cmd
    for spec in "$@"; do
        tab_index=$((tab_index + 1))
        IFS='|' read -r tab_name workdir cmd <<< "$spec"
        tab_name="${tab_name:-tab-$tab_index}"

        # Escape backslashes and double quotes for KDL string content
        escaped_name="${tab_name//\\/\\\\}"
        escaped_name="${escaped_name//\"/\\\"}"
        escaped_workdir="${workdir//\\/\\\\}"
        escaped_workdir="${escaped_workdir//\"/\\\"}"

        if [[ -z "$cmd" ]]; then
            # Shell-only tab — just open bash in the workdir
            printf '    tab name="%s" cwd="%s" {\n' \
                "$escaped_name" "$escaped_workdir" >> "$filepath"
            printf '        pane\n' >> "$filepath"
            printf '    }\n' >> "$filepath"
        else
            # Command tab — run command, then stay open with a shell
            escaped_cmd="${cmd//\\/\\\\}"
            escaped_cmd="${escaped_cmd//\"/\\\"}"
            printf '    tab name="%s" cwd="%s" {\n' \
                "$escaped_name" "$escaped_workdir" >> "$filepath"
            printf '        pane command="bash" {\n' >> "$filepath"
            printf '            args "-c" "%s; exec bash"\n' "$escaped_cmd" >> "$filepath"
            printf '        }\n' >> "$filepath"
            printf '    }\n' >> "$filepath"
        fi
    done

    printf '}\n' >> "$filepath"
}

# Launch a development workspace terminal.
#
# Approach (two-phase launch — avoids default_layout and partial config files):
#   1. Kill any stale session with the target name (clean slate)
#   2. Switch to target virtual desktop
#   3. Launch bare Zellij in Alacritty — session created with full default
#      config (tab-bar & status-bar plugins load → UX frame stays visible)
#   4. Wait for session daemon to appear (polling, with timeout)
#   5. Apply layout to running session — adds all N tabs with proper cwd
#   6. Close the auto-created default tab (best-effort)
#
# Usage: launch_term <desk-index> <label> <layout-file-path>
launch_term() {
    local desk_index="$1"
    local label="$2"
    local layout_file="$3"
    local session_name="lighter-dev-${label}"

    log_info "Launching «${label}» on desktop $((desk_index + 1)) …"

    # Step 1: Kill stale session (clean slate for fresh layout)
    zellij kill-sessions "$session_name" 2>/dev/null || true

    # Step 2: Switch to target virtual desktop
    switch_desktop "$desk_index"

    # Step 3: Launch bare Zellij via Alacritty — full default config loads
    # (tab-bar and status-bar plugins intact → UX frame visible)
    alacritty -e zellij --session "$session_name" &>/dev/null &

    # Step 4: Wait for the session daemon to be ready
    local timeout=$SESSION_READY_TIMEOUT
    while (( timeout > 0 )); do
        if zellij list-sessions 2>/dev/null | awk '{print $1}' | grep -qxF "$session_name"; then
            break
        fi
        sleep 1
        (( timeout-- ))
    done

    if (( timeout == 0 )); then
        log_warn "Session «${session_name}» not ready within ${SESSION_READY_TIMEOUT}s — skipping layout"
        return 1
    fi

    # Brief extra settling time for the session daemon
    sleep 0.5

    # Step 5: Apply layout to the running session
    # zellij --layout <file> --session <name> adds all tabs with proper cwd
    if ! zellij --layout "$layout_file" --session "$session_name" &>/dev/null; then
        log_warn "Failed to apply layout to session «${session_name}»"
    fi

    # Step 6: Close the auto-created default tab
    # Best-effort — if this fails, one extra shell tab persists (cosmetic)
    zellij --session "$session_name" action go-to-tab 0 &>/dev/null || true
    zellij --session "$session_name" action close-tab &>/dev/null || true
}

# ── Main ───────────────────────────────────────────────────────────────────

main() {
    case "${1:-}" in
        --help|-h)
            sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
            exit 0
            ;;
        --dry-run|--dry)
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
            log_info "  lighterbird:     omaster"
            log_info "  semantika:       omaster"
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

    # ── Layout directory ───────────────────────────────────────────────
    mkdir -p "$LAYOUT_DIR"
    # Remove stale layouts from previous runs (they are re-created below).
    rm -f "$LAYOUT_DIR"/lighter-dev-*.kdl

    echo ""

    # ── Workspace 1: lighter-config + lighterbird + semantika ──────────
    log_info "=== Workspace 1 ==="
    gen_layout "$LAYOUT_DIR/lighter-dev.kdl" \
        "lighter-config|${DIR_LIGHTER_CONFIG}|nvim README.md" \
        "lighter-config-2|${DIR_LIGHTER_CONFIG}|" \
        "lighterbird|${DIR_LIGHTERBIRD}|git pull" \
        "lighterbird-2|${DIR_LIGHTERBIRD}|" \
        "semantika|${DIR_SEMANTIKA}|git pull" \
        "semantika-2|${DIR_SEMANTIKA}|"
    launch_term "$DESK_WS1" "lighter-dev" "$LAYOUT_DIR/lighter-dev.kdl"

    # ── Workspace 3: autish repl ───────────────────────────────────────
    log_info "=== Workspace 3 ==="
    gen_layout "$LAYOUT_DIR/autish.kdl" \
        "repl-sistemo|${DIR_AUTISH}|${CMD_A_REPL_SISTEMO}" \
        "shell|${DIR_AUTISH}|" \
        "repl-semantika|${DIR_AUTISH}|${CMD_A_REPL_SEMANTIKA}"
    launch_term "$DESK_WS3" "autish" "$LAYOUT_DIR/autish.kdl"

    # ── Workspace 4: opencode-config + scratch ─────────────────────────
    log_info "=== Workspace 4 ==="
    gen_layout "$LAYOUT_DIR/opencode.kdl" \
        "opencode|${DIR_BASCULER_OPENCODE}|${CMD_OPENCODE}" \
        "shell|${DIR_BASCULER_OPENCODE}|"
    launch_term "$DESK_WS4" "opencode" "$LAYOUT_DIR/opencode.kdl"

    gen_layout "$LAYOUT_DIR/scratch.kdl" \
        "tmp|${DIR_SCRATCH}|nvim ./tmp.md" \
        "lighterbird-notes|${DIR_SCRATCH}|nvim ./lighterbird/lighterbird-1.md" \
        "semantika-notes|${DIR_SCRATCH}|nvim ./semantika/semantika-1.md"
    launch_term "$DESK_WS4" "scratch" "$LAYOUT_DIR/scratch.kdl"

    # ── Workspace 5: lighterbird + semantika master ────────────────────
    log_info "=== Workspace 5 ==="
    gen_layout "$LAYOUT_DIR/lighterbird-master.kdl" \
        "master|${DIR_LIGHTERBIRD}|${CMD_MASTER}"
    launch_term "$DESK_WS5" "lighterbird-master" "$LAYOUT_DIR/lighterbird-master.kdl"

    gen_layout "$LAYOUT_DIR/semantika-master.kdl" \
        "master|${DIR_SEMANTIKA}|${CMD_MASTER}"
    launch_term "$DESK_WS5" "semantika-master" "$LAYOUT_DIR/semantika-master.kdl"

    echo ""
    log_ok "All terminals launched. Zellij sessions are running."
    log_info "Re-attach later:  zellij list-sessions  →  zellij attach <session-name>"
}

main "$@"
