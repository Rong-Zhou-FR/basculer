#!/usr/bin/env bash
#
# install.sh — Install and configure Alacritty + Zellij
#
# Usage:
#   ./install.sh            # full install (binaries + configs)
#   ./install.sh --config   # config only (skip binary checks)
#   ./install.sh --help     # show this message
#
# This script is idempotent — it checks each component and skips
# anything already installed/set up.
#
# Prerequisites: Debian-based Linux (Debian/Ubuntu/Mint/…)

set -euo pipefail

# ── Constants ────────────────────────────────────────────────────────────────
ALACRITTY_BIN="alacritty"
ALACRITTY_CONFIG_DIR="${HOME}/.config/alacritty"
ALACRITTY_CONFIG_FILE="${ALACRITTY_CONFIG_DIR}/alacritty.toml"

ZELLIJ_BIN="zellij"
ZELLIJ_CONFIG_DIR="${HOME}/.config/zellij"
ZELLIJ_CONFIG_FILE="${ZELLIJ_CONFIG_DIR}/config.kdl"
ZELLIJ_VERSION="0.44.3"
ZELLIJ_URI="https://github.com/zellij-org/zellij/releases/download/v${ZELLIJ_VERSION}/zellij-x86_64-unknown-linux-musl.tar.gz"

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Helpers ──────────────────────────────────────────────────────────────────

info()  { printf '\e[34m[INFO]\e[0m  %s\n' "$*"; }
ok()    { printf '\e[32m[OK]\e[0m    %s\n' "$*"; }
skip()  { printf '\e[33m[SKIP]\e[0m  %s\n' "$*"; }
err()   { printf '\e[31m[ERROR]\e[0m %s\n' "$*" >&2; }
warn()  { printf '\e[33m[WARN]\e[0m  %s\n' "$*"; }

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
        # Use -A (askpass) if SUDO_ASKPASS is set; otherwise fall back to
        # plain sudo which prompts interactively when a tty is available.
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

# ── Pre-checks ───────────────────────────────────────────────────────────────

need_cmd "apt-get"
need_cmd "tar"

if ! grep -qi 'debian\|ubuntu\|mint\|pop\|kali\|elementary\|zorin' /etc/os-release 2>/dev/null; then
    warn "This script targets Debian-based distributions."
    confirm "Continue anyway?" || exit 0
fi

# Cache sudo credentials up front so the rest of the script runs without
# interactive prompts.  If the user cancels here, nothing has been changed.
if [[ $EUID -ne 0 ]]; then
    if [[ -t 0 ]]; then
        info "Requesting sudo access (will be cached for the duration of this script)…"
        sudo -v || { err "sudo required but not granted"; exit 1; }
        # Keep the sudo timestamp valid while the script runs.
        while true; do sudo -n true; sleep 60; kill -0 "$$" 2>/dev/null || exit; done 2>/dev/null &
    else
        # Non-interactive — try once; if it fails, individual commands will
        # prompt via their own sudo invocation when run in a real terminal.
        sudo -n true 2>/dev/null || \
            warn "Running non-interactively without cached sudo. Commands that need root will prompt individually."
    fi
fi

# ── 1. Alacritty ─────────────────────────────────────────────────────────────

install_alacritty() {
    echo ""
    info "=== Alacritty ==="

    if command -v "$ALACRITTY_BIN" &>/dev/null; then
        local ver
        ver="$("$ALACRITTY_BIN" --version 2>/dev/null || true)"
        skip "alacritty already installed ($ver)"
        return 0
    fi

    info "Installing alacritty via apt…"
    sudo_if_needed apt-get update -qq
    sudo_if_needed apt-get install -y "$ALACRITTY_BIN"
    ok "alacritty installed ($("$ALACRITTY_BIN" --version 2>/dev/null))"
}

# ── 2. Alacritty config ──────────────────────────────────────────────────────

setup_alacritty_config() {
    echo ""
    info "=== Alacritty config ==="

    if [[ -f "$ALACRITTY_CONFIG_FILE" ]]; then
        skip "alacritty config already exists at ${ALACRITTY_CONFIG_FILE}"
        return 0
    fi

    mkdir -p "$ALACRITTY_CONFIG_DIR"

    cat > "$ALACRITTY_CONFIG_FILE" << 'ALACRITTY_TOML'
# Alacritty configuration — https://alacritty.org/config-alacritty.html
#
# This is a minimal starter config. Customise to taste.

[env]
TERM = "alacritty"

[window]
padding = { x = 4, y = 4 }
decorations = "full"
opacity = 0.95

[scrolling]
history = 10000

[font]
size = 11

[font.normal]
family = "monospace"
style = "Regular"

[font.bold]
family = "monospace"
style = "Bold"

[font.italic]
family = "monospace"
style = "Italic"

[font.bold_italic]
family = "monospace"
style = "Bold Italic"

[colors.primary]
background = "#1e1e2e"
foreground = "#cdd6f4"

[colors.normal]
black   = "#45475a"
red     = "#f38ba8"
green   = "#a6e3a1"
yellow  = "#f9e2af"
blue    = "#89b4fa"
magenta = "#f5c2e7"
cyan    = "#94e2d5"
white   = "#bac2de"

[colors.bright]
black   = "#585b70"
red     = "#f38ba8"
green   = "#a6e3a1"
yellow  = "#f9e2af"
blue    = "#89b4fa"
magenta = "#f5c2e7"
cyan    = "#94e2d5"
white   = "#a6adc8"

[cursor]
style = "Block"

[selection]
semantic_escape_chars = ",│`|:\"' ()[]{}<>"

[general]
live_config_reload = true

[keyboard]
bindings = [
    { key = "V",         mods = "Control|Shift", action = "Paste" },
    { key = "C",         mods = "Control|Shift", action = "Copy" },
    { key = "Key0",      mods = "Control",       action = "ResetFontSize" },
    { key = "Equals",    mods = "Control",       action = "IncreaseFontSize" },
    { key = "Minus",     mods = "Control",       action = "DecreaseFontSize" },
]
ALACRITTY_TOML

    ok "alacritty config created at ${ALACRITTY_CONFIG_FILE}"
}

# ── 3. Zellij ────────────────────────────────────────────────────────────────

install_zellij() {
    echo ""
    info "=== Zellij ==="

    if command -v "$ZELLIJ_BIN" &>/dev/null; then
        local ver
        ver="$("$ZELLIJ_BIN" --version 2>/dev/null || true)"
        skip "zellij already installed ($ver)"
        return 0
    fi

    local tmpdir
    tmpdir="$(mktemp -d)"
    local archive="${tmpdir}/zellij.tar.gz"

    info "Downloading zellij v${ZELLIJ_VERSION} from GitHub…"
    curl -#fSL "$ZELLIJ_URI" -o "$archive" || {
        err "Failed to download zellij from ${ZELLIJ_URI}"
        rm -rf "$tmpdir"
        exit 1
    }

    info "Extracting…"
    tar -xzf "$archive" -C "$tmpdir"

    local dest="/usr/local/bin/${ZELLIJ_BIN}"
    info "Installing to ${dest}…"
    sudo_if_needed install -m 0755 "${tmpdir}/zellij" "$dest"
    rm -rf "$tmpdir"

    ok "zellij installed ($("$ZELLIJ_BIN" --version 2>/dev/null))"
}

# ── 4. Zellij config ─────────────────────────────────────────────────────────

setup_zellij_config() {
    echo ""
    info "=== Zellij config ==="

    if [[ -f "$ZELLIJ_CONFIG_FILE" ]]; then
        skip "zellij config already exists at ${ZELLIJ_CONFIG_FILE}"
        return 0
    fi

    mkdir -p "$ZELLIJ_CONFIG_DIR"

    cat > "$ZELLIJ_CONFIG_FILE" << 'ZELLIJ_KDL'
// Zellij configuration — https://zellij.dev/documentation/configuration.html
//
// Minimal starter config. Customise to taste.

theme: "catppuccin-mocha"

pane_frames: true
simplified_ui: true

// Unbind defaults that conflict with bash/nvim.
// Note: each key combo is a single string, space-separated modifier + key.
keybinds {
    normal {
        unbind "Ctrl q"
        unbind "Ctrl p"
        unbind "Ctrl n"
    }
}
ZELLIJ_KDL

    ok "zellij config created at ${ZELLIJ_CONFIG_FILE}"
}

# ── Post-install hints ───────────────────────────────────────────────────────

print_hints() {
    echo ""
    info "=== Next steps ==="

    local need_logout=false

    if command -v "$ALACRITTY_BIN" &>/dev/null; then
        # Alacritty uses the desktop entry for the system terminal; no manual step needed.
        :
    else
        need_logout=true
    fi

    if [[ ! -f "$ALACRITTY_CONFIG_FILE" ]]; then
        warn "alacritty config was not written — create manually at ${ALACRITTY_CONFIG_FILE}"
    fi

    if command -v "$ZELLIJ_BIN" &>/dev/null; then
        echo "  Start Zellij:                   zellij"
        echo "  Attach to existing session:     zellij attach"
        echo "  List sessions:                  zellij list-sessions"
        echo "  Configuration docs:             https://zellij.dev/documentation/"
    fi

    if $need_logout; then
        warn "Log out and back in for desktop entries to take effect."
    fi

    echo ""
    echo "  Alacritty config:  ${ALACRITTY_CONFIG_FILE}"
    echo "  Zellij config:     ${ZELLIJ_CONFIG_FILE}"
    echo ""
}

# ── Main ─────────────────────────────────────────────────────────────────────

main() {
    case "${1:-}" in
        --help|-h)
            sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
            exit 0
            ;;
        --config|-c)
            setup_alacritty_config
            setup_zellij_config
            print_hints
            exit 0
            ;;
        --*)
            err "Unknown option: $1"
            exit 1
            ;;
    esac

    install_alacritty
    setup_alacritty_config

    install_zellij
    setup_zellij_config

    print_hints
}

main "$@"
