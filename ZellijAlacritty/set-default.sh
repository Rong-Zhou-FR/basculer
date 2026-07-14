#!/usr/bin/env bash
#
# set-default.sh — Configure Alacritty as default terminal + Zellij auto-start
#
# Usage:
#   ./set-default.sh                   # interactive: ask what to do
#   ./set-default.sh --yes             # set Alacritty as default, auto-start Zellij
#   ./set-default.sh --restore         # list backups, pick one to restore
#   ./set-default.sh --restore <N>     # restore backup #N directly
#   ./set-default.sh --help            # show this message
#
# Changes made:
#   1. Set Alacritty as the default terminal emulator
#      - System-wide: update-alternatives (requires sudo)
#      - DE gsettings: schema detected from XDG_CURRENT_DESKTOP
#   2. Add a block to ~/.bashrc that auto-starts Zellij
#      inside any non-SSH, non-TTY graphical terminal.
#
# Each --yes creates a timestamped snapshot of the previous state
# in ~/.config/zellij-alacritty/backups/.  --restore lists them
# and lets you choose which to revert to.

set -euo pipefail

# ── Constants ────────────────────────────────────────────────────────────────

BACKUP_DIR="${HOME}/.config/zellij-alacritty/backups"
BACKUP_PREFIX="state"
BASHRC="${HOME}/.bashrc"
MARKER_BEGIN="# >>> basculer zellij-alacritty auto-start >>>"
MARKER_END="# <<< basculer zellij-alacritty auto-start <<<"

# Known gsettings schemas that control the default terminal per desktop.
GSETTINGS_TERMINAL_SCHEMAS=(
    org.gnome.desktop.default-applications.terminal
    org.cinnamon.desktop.default-applications.terminal
    org.mate.applications-terminal
)

# ── Helpers ──────────────────────────────────────────────────────────────────

info()  { printf '\e[34m[INFO]\e[0m  %s\n' "$*"; }
ok()    { printf '\e[32m[OK]\e[0m    %s\n' "$*"; }
skip()  { printf '\e[33m[SKIP]\e[0m  %s\n' "$*"; }
warn()  { printf '\e[33m[WARN]\e[0m  %s\n' "$*"; }
err()   { printf '\e[31m[ERROR]\e[0m %s\n' "$*" >&2; }

need_cmd() {
    if ! command -v "$1" &>/dev/null; then
        err "Missing required command: $1"
        exit 1
    fi
}

confirm() {
    local prompt="$1"
    local answer
    read -r -p "${prompt} [Y/n] " answer
    [[ -z "$answer" || "$answer" =~ ^[Yy] ]]
}

sudo_if_needed() {
    if [[ $EUID -eq 0 ]]; then
        "$@"
    elif command -v sudo &>/dev/null; then
        if [[ -n "${SUDO_ASKPASS:-}" ]]; then
            sudo -A "$@"
        else
            sudo "$@"
        fi
    else
        err "Need root to run: $*"
        exit 1
    fi
}

try_sudo() {
    # Like sudo_if_needed, but doesn't abort on failure in non-interactive
    # contexts — returns 1 instead.
    if [[ $EUID -eq 0 ]]; then
        "$@"
    elif command -v sudo &>/dev/null; then
        if [[ -n "${SUDO_ASKPASS:-}" ]]; then
            sudo -A "$@" 2>/dev/null || { warn "sudo failed (non-interactive?) — skipping: $*"; return 1; }
        elif [[ -t 0 ]]; then
            sudo "$@"
        else
            sudo -n true 2>/dev/null || { warn "sudo unavailable non-interactively — skipping: $*"; return 1; }
            sudo "$@"
        fi
    else
        err "Need root to run: $*"
        exit 1
    fi
}

# ── Pre-checks ───────────────────────────────────────────────────────────────

NEEDS_SUDO=false
check_system() {
    if ! command -v update-alternatives &>/dev/null; then
        err "update-alternatives not found — not a Debian-based system?"
        exit 1
    fi
    if ! command -v alacritty &>/dev/null; then
        err "alacritty is not installed. Run ./install.sh first."
        exit 1
    fi
    if ! command -v zellij &>/dev/null; then
        err "zellij is not installed. Run ./install.sh first."
        exit 1
    fi
    if [[ $EUID -ne 0 ]]; then
        NEEDS_SUDO=true
    fi
}

cache_sudo() {
    if ! $NEEDS_SUDO; then return 0; fi
    if [[ -t 0 ]]; then
        info "Requesting sudo access (cached for the rest of the script)…"
        sudo -v || { err "sudo required but not granted"; exit 1; }
        while true; do sudo -n true; sleep 60; kill -0 "$$" 2>/dev/null || exit; done 2>/dev/null &
    else
        sudo -n true 2>/dev/null || \
            warn "Running non-interactively without cached sudo. Commands that need root will prompt individually."
    fi
}

# ── Desktop environment detection ─────────────────────────────────────────

detect_terminal_schemas() {
    local de="${XDG_CURRENT_DESKTOP:-}"

    case "$de" in
        *GNOME*|*Unity*|*Budgie*)
            echo "org.gnome.desktop.default-applications.terminal"
            ;;
        *Cinnamon*)
            echo "org.cinnamon.desktop.default-applications.terminal"
            ;;
        *MATE*)
            echo "org.mate.applications-terminal"
            ;;
        *XFCE*)
            echo ""
            ;;
        *)
            for s in "${GSETTINGS_TERMINAL_SCHEMAS[@]}"; do
                if gsettings list-schemas 2>/dev/null | grep -qF "$s"; then
                    echo "$s"
                fi
            done
            ;;
    esac
}

# ── Backup ───────────────────────────────────────────────────────────────────

save_backup() {
    mkdir -p "$BACKUP_DIR"

    local ts
    ts="$(date '+%Y%m%d-%H%M%S')"
    local file="${BACKUP_DIR}/${BACKUP_PREFIX}-${ts}"

    # Human-readable header
    echo "# Created: $(date '+%Y-%m-%d %H:%M:%S')" > "$file"
    echo "# Desktop: ${XDG_CURRENT_DESKTOP:-?}" >> "$file"

    # System-level update-alternatives target
    local alt_target
    alt_target=$(readlink -f /etc/alternatives/x-terminal-emulator 2>/dev/null || echo "unset")
    echo "ALTERNATIVES=${alt_target}" >> "$file"

    # All known terminal gsettings
    if command -v gsettings &>/dev/null; then
        local _s
        for _s in "${GSETTINGS_TERMINAL_SCHEMAS[@]}"; do
            local val
            val=$(gsettings get "$_s" exec 2>/dev/null || true)
            if [[ -n "$val" ]]; then
                # Replace dots AND hyphens — bash variable names can't contain hyphens
                local key
                key="GSS_$(echo "$_s" | tr '.' '_' | tr '-' '_')"
                echo "${key}=${val}" >> "$file"
            fi
        done
    fi

    local display_name="${alt_target##*/}"  # strip path → "gnome-terminal.wrapper"
    display_name="${display_name%.wrapper}" # strip .wrapper → "gnome-terminal"
    [[ "$alt_target" == "unset" ]] && display_name="none"

    info "Backup saved: ${file} (terminal: ${display_name})"
}

list_backups() {
    # Prints backup files sorted oldest-first, one per line.
    # Format: <path>|<timestamp>|<alt_name>
    local f
    for f in "$BACKUP_DIR"/${BACKUP_PREFIX}-*; do
        [[ -f "$f" ]] || continue
        local ts="${f##*-}"           # YYYYMMDD-HHMMSS
        local display="${ts:0:10} ${ts:11:2}:${ts:13:2}:${ts:15:2}"  # YYYY-MM-DD HH:MM:SS
        # Extract ALTERNATIVES value from the backup
        local alt
        alt=$(grep '^ALTERNATIVES=' "$f" | head -1 | cut -d= -f2- || echo "unset")
        local name="${alt##*/}"
        name="${name%.wrapper}"
        [[ "$alt" == "unset" ]] && name="none"
        echo "$f|${display}|${name}"
    done | sort -t'|' -k2
}

show_backups() {
    local -a lines
    mapfile -t lines < <(list_backups)

    if [[ ${#lines[@]} -eq 0 ]]; then
        echo "  No backups found."
        return 1
    fi

    echo ""
    echo "  #  Date                Previous terminal"
    echo "  --  ------------------ ----------------"
    local i
    for i in "${!lines[@]}"; do
        local name
        name=$(echo "${lines[$i]}" | cut -d'|' -f3)
        local date
        date=$(echo "${lines[$i]}" | cut -d'|' -f2)
        printf "  %2d) %s  %s\n" $((i+1)) "$date" "$name"
    done
    echo ""

    return 0
}

# ── Restore ──────────────────────────────────────────────────────────────────

restore_backup() {
    local backup_file="$1"
    local index="$2"  # for display

    echo ""
    info "=== Restoring backup #${index}: $(basename "$backup_file") ==="

    # shellcheck disable=SC1090
    source "$backup_file"

    local success=true

    # 1. Restore system-level alternative
    if [[ -n "${ALTERNATIVES:-}" ]]; then
        if [[ "$ALTERNATIVES" == "unset" ]]; then
            info "No previous terminal was registered — removing alacritty from alternatives"
            try_sudo update-alternatives --remove x-terminal-emulator "$(command -v alacritty)" 2>/dev/null || success=false
        elif [[ -x "$ALTERNATIVES" ]]; then
            info "Restoring system terminal to: ${ALTERNATIVES}"
            try_sudo update-alternatives --install /usr/bin/x-terminal-emulator \
                x-terminal-emulator "$ALTERNATIVES" 10 || success=false
            try_sudo update-alternatives --set x-terminal-emulator "$ALTERNATIVES" || success=false
        else
            warn "Previous system terminal (${ALTERNATIVES}) no longer exists on disk."
            success=false
        fi
    fi

    # 2. Restore gsettings
    if command -v gsettings &>/dev/null; then
        local _s
        for _s in "${GSETTINGS_TERMINAL_SCHEMAS[@]}"; do
            local key
            key="GSS_$(echo "$_s" | tr '.' '_' | tr '-' '_')"
            local saved_val
            saved_val="${!key:-}"
            if [[ -n "$saved_val" ]]; then
                info "Restoring ${_s}.exec to ${saved_val}"
                gsettings set "$_s" exec "${saved_val}" 2>/dev/null || \
                    warn "Could not restore ${_s}.exec"
            fi
        done
    fi

    if $success; then
        rm -f "$backup_file"
        ok "Backup #${index} applied and removed."
    else
        warn "Restore had issues. Backup preserved at: ${backup_file}"
    fi
}

pick_backup() {
    local -a lines
    mapfile -t lines < <(list_backups)

    if [[ ${#lines[@]} -eq 0 ]]; then
        echo ""
        info "No backups found in ${BACKUP_DIR}"
        return 1
    fi

    # Single backup — non-interactive, just use it
    if [[ ${#lines[@]} -eq 1 ]]; then
        local file
        file=$(echo "${lines[0]}" | cut -d'|' -f1)
        restore_backup "$file" 1
        return $?
    fi

    echo ""
    info "Multiple backups found. Choose which to restore:"
    show_backups

    local choice
    read -r -p "Restore which backup? [1-${#lines[@]}, q to cancel]: " choice

    case "$choice" in
        q|Q|cancel|"")
            info "Restore cancelled."
            return 1
            ;;
        *[!0-9]*)
            err "Invalid choice: $choice"
            return 1
            ;;
        *)
            if [[ "$choice" -lt 1 || "$choice" -gt "${#lines[@]}" ]]; then
                err "Choice out of range (1-${#lines[@]})"
                return 1
            fi
            local file
            file=$(echo "${lines[$((choice-1))]}" | cut -d'|' -f1)
            restore_backup "$file" "$choice"
            return $?
            ;;
    esac
}

# ── Set Alacritty as default ────────────────────────────────────────────────

set_default_terminal() {
    echo ""
    info "=== Default terminal emulator ==="

    local alacritty_path
    alacritty_path="$(command -v alacritty)"
    local needs_change=false

    # 1. System-level update-alternatives
    local current
    current=$(readlink -f /etc/alternatives/x-terminal-emulator 2>/dev/null || echo "none")

    if [[ "$current" != "$alacritty_path" ]]; then
        save_backup

        if ! grep -q "x-terminal-emulator.*$(basename "$alacritty_path")" /var/lib/dpkg/alternatives/x-terminal-emulator 2>/dev/null; then
            info "Registering Alacritty with update-alternatives…"
            try_sudo update-alternatives --install /usr/bin/x-terminal-emulator \
                x-terminal-emulator "$alacritty_path" 20 || { warn "Skipping system-wide terminal setup"; }
        fi

        info "Setting Alacritty as the system terminal (update-alternatives)…"
        try_sudo update-alternatives --set x-terminal-emulator "$alacritty_path" || \
            warn "Could not set system terminal (non-interactive?)"
        needs_change=true
    else
        skip "Alacritty is already the system default (update-alternatives)"
    fi

    # 2. Desktop-environment gsettings (per-user, no sudo)
    if command -v gsettings &>/dev/null; then
        local schemas
        schemas=$(detect_terminal_schemas)
        if [[ -z "$schemas" ]]; then
            warn "Unknown desktop environment (${XDG_CURRENT_DESKTOP:-?})."
            warn "Set Alacritty as default manually in your DE's keyboard settings."
        else
            for _schema in $schemas; do
                local _current_val _current_clean
                _current_val="$(gsettings get "$_schema" exec 2>/dev/null || true)"
                _current_clean="$(echo "$_current_val" | tr -d "'")"

                if [[ "$_current_clean" != "alacritty" && "$_current_clean" != "$(basename "$alacritty_path")" ]]; then
                    if ! $needs_change; then
                        save_backup
                    fi
                    info "Setting ${_schema}.exec to alacritty…"
                    gsettings set "$_schema" exec "alacritty" 2>/dev/null || \
                        warn "Could not set ${_schema}.exec"
                    needs_change=true
                else
                    skip "${_schema}.exec already set to alacritty"
                fi
            done
        fi
    fi

    if $needs_change; then
        ok "Default terminal emulator set to Alacritty ($alacritty_path)"
    fi
}

# ── Zellij auto-start in bashrc ──────────────────────────────────────────────

zellij_autostart_block() {
    cat << 'AUTOSTART'

# >>> basculer zellij-alacritty auto-start >>>
# Automatically start Zellij inside graphical terminals
# (not SSH sessions, not TTY consoles, not pipes).
# Each terminal window gets its own fresh Zellij session.
# This block was added by ZellijAlacritty/set-default.sh
if [[ -z "$ZELLIJ" && -z "$SSH_TTY" && "$TERM" != "dumb" && "$(tty)" != /dev/tty* ]]; then
    # Don't auto-start if already inside a Zellij session or a non-interactive shell
    if [[ -t 0 && $- == *i* ]]; then
        zellij
    fi
fi
# <<< basculer zellij-alacritty auto-start <<<
AUTOSTART
}

add_zellij_autostart() {
    echo ""
    info "=== Zellij auto-start ==="

    if grep -qF "$MARKER_BEGIN" "$BASHRC" 2>/dev/null; then
        skip "Zellij auto-start block already present in ${BASHRC}"
        return 0
    fi

    if [[ ! -f "$BASHRC" ]]; then
        warn "${BASHRC} does not exist — creating it"
        touch "$BASHRC"
    fi

    {
        echo ""
        zellij_autostart_block
    } >> "$BASHRC"

    ok "Zellij auto-start added to ${BASHRC}"
}

remove_zellij_autostart() {
    echo ""
    info "=== Zellij auto-start ==="

    if ! grep -qF "$MARKER_BEGIN" "$BASHRC" 2>/dev/null; then
        skip "No Zellij auto-start block found in ${BASHRC}"
        return 0
    fi

    local tmpfile
    tmpfile="$(mktemp)"
    sed "/^${MARKER_BEGIN}$/,/^${MARKER_END}$/d" "$BASHRC" > "$tmpfile"
    mv "$tmpfile" "$BASHRC"

    ok "Zellij auto-start removed from ${BASHRC}"
}

# ── Actions ──────────────────────────────────────────────────────────────────

do_set_default() {
    check_system
    cache_sudo
    set_default_terminal || warn "Failed to set default terminal — continuing with Zellij auto-start."
    add_zellij_autostart

    echo ""
    ok "All set! Open a new Alacritty window — Zellij will start automatically."
}

do_restore() {
    local index="${1:-}"

    if [[ -n "$index" ]]; then
        # Restore a specific backup by 1-based index
        local -a lines
        mapfile -t lines < <(list_backups)
        if [[ ${#lines[@]} -eq 0 ]]; then
            err "No backups found."
            exit 1
        fi
        if ! [[ "$index" =~ ^[0-9]+$ ]]; then
            err "Invalid backup number: $index"
            exit 1
        fi
        if [[ "$index" -lt 1 || "$index" -gt "${#lines[@]}" ]]; then
            err "Backup number out of range (1-${#lines[@]})"
            exit 1
        fi
        local file
        file=$(echo "${lines[$((index-1))]}" | cut -d'|' -f1)
        check_system
        cache_sudo
        restore_backup "$file" "$index"
        remove_zellij_autostart
    else
        # Interactive pick
        check_system
        cache_sudo
        pick_backup || true
        remove_zellij_autostart
    fi

    echo ""
    ok "Changes undone. Open a new terminal to see the effect."
}

do_interactive() {
    echo ""
    echo "What would you like to do?"
    echo "  1) Set Alacritty as default terminal + auto-start Zellij"
    echo "  2) Undo changes (restore previous terminal, remove Zellij auto-start)"
    echo ""
    read -r -p "Choose [1/2]: " choice

    case "$choice" in
        1) do_set_default ;;
        2) do_restore ;;
        *) err "Invalid choice: $choice"; exit 1 ;;
    esac
}

# ── Main ─────────────────────────────────────────────────────────────────────

main() {
    case "${1:-}" in
        --help|-h)
            sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
            exit 0
            ;;
        --yes|-y)
            do_set_default
            ;;
        --restore|-r)
            do_restore "${2:-}"
            ;;
        "")
            do_interactive
            ;;
        --*)
            err "Unknown option: $1"
            exit 1
            ;;
    esac
}

main "$@"
