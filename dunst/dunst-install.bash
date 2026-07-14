#!/usr/bin/env bash
# dunst-install.bash
#
# Replace Cinnamon's built-in notifications with dunst for per-app
# notification filtering on Linux Mint / Cinnamon DE.
#
# Run:  bash dunst/dunst-install.bash
#
# Cinnamon (as of v6.4) has NO per-app notification controls in either
# the GUI or gsettings.  dunst fills that gap via simple config rules.
#
# This script:
#   1. Installs dunst (apt)
#   2. Backs up any existing ~/.config/dunst/
#   3. Writes a comprehensive dunstrc with per-app blocking examples
#      (uses POSIX regex — enable_posix_regex = true)
#   4. Sets Cinnamon's allow-other-notification-handlers → true
#   5. Unmasks, enables, and starts dunst via systemd --user
#   6. Restarts Cinnamon shell (in-place, keeps all apps) so it releases
#      the org.freedesktop.Notifications D-Bus name
#   7. Restarts dunst.service so it claims the D-Bus name
#   8. Verifies dunst OWNS the D-Bus name
#   9. Sends a test notification

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Colour

info()  { echo -e "${GREEN}✓${NC} $*"; }
warn()  { echo -e "${YELLOW}⚠${NC} $*"; }
err()   { echo -e "${RED}✗${NC} $*" >&2; }
header(){ echo -e "\n${BOLD}── $* ──${NC}"; }

# ── Step 1: Install dunst ────────────────────────────────────────────
header "Installing dunst"

if dpkg -s dunst &>/dev/null 2>&1; then
    info "dunst already installed ($(dpkg -s dunst | grep ^Version | cut -d' ' -f2))"
else
    sudo apt update -qq && sudo apt install -y dunst
    info "dunst installed"
fi

# ── Step 2: Backup existing config ──────────────────────────────────
header "Config directory"

if [[ -d "$HOME/.config/dunst" ]]; then
    BACKUP="$HOME/.config/dunst.bak.$(date +%Y%m%d-%H%M%S)"
    mv "$HOME/.config/dunst" "$BACKUP"
    info "existing config backed up → $BACKUP"
fi

mkdir -p "$HOME/.config/dunst"

# ── Step 3: Write dunstrc ────────────────────────────────────────────
header "Writing ~/.config/dunst/dunstrc"

cat > "$HOME/.config/dunst/dunstrc" << 'DUNSTRC'
########################################################################
# dunstrc — dunst notification daemon configuration
# See: man 5 dunst
########################################################################

[global]
    # Enable POSIX extended regular expressions for rule matching
    # (more powerful than default glob; "abc" matches any summary containing "abc")
    enable_posix_regex = true

    # Monitor (0 = primary, name like "HDMI-1", or "all")
    monitor = 0

    # Geometry
    origin = top-right
    offset = 10x50
    width = 350
    height = 300
    notification_limit = 15

    # Timing
    timeout = 5               # default 5s
    idle_threshold = 0        # don't timeout when idle (0 = disable)
    show_age_threshold = 60   # show age after 60s

    # Font
    font = "Ubuntu 10"

    # Appearance
    padding = 8
    horizontal_padding = 8
    text_icon_padding = 4
    frame_width = 2
    separator_height = 2
    gap_size = 0
    corner_radius = 5
    transparency = 0

    # Icons
    enable_recursive_icon_lookup = true
    icon_theme = "Mint-Y"
    min_icon_size = 24
    max_icon_size = 64
    icon_position = left

    # Progress bar
    progress_bar = true
    progress_bar_height = 8
    progress_bar_frame_width = 1
    progress_bar_min_width = 150
    progress_bar_max_width = 300
    progress_bar_corner_radius = 2

    # Behaviour
    sort = true
    stack_duplicates = true
    hide_duplicate_count = false
    indicate_hidden = true
    sticky_history = true
    history_length = 50
    show_indicators = true
    markup = no               # strip HTML markup from notifications
    word_wrap = true
    ellipsize = middle
    ignore_newline = false
    line_height = 0

    # Mouse
    mouse_left_click   = close_current
    mouse_middle_click = do_action, close_current
    mouse_right_click  = close_all

    # Scripts
    browser = /usr/bin/xdg-open

########################################################################
# URGENCY DEFAULTS
########################################################################

[urgency_low]
    background = "#2e3436"
    foreground = "#aaaaaa"
    highlight  = "#4e9a06"
    frame_color = "#3f3f3f"
    timeout = 4
    icon = "dialog-information-symbolic"

[urgency_normal]
    background = "#2e3436"
    foreground = "#d3d7cf"
    highlight  = "#4e9a06"
    frame_color = "#4e9a06"
    timeout = 5
    icon = "dialog-information-symbolic"

[urgency_critical]
    background = "#300000"
    foreground = "#ffffff"
    highlight  = "#cc0000"
    frame_color = "#cc0000"
    timeout = 0                # never auto-dismiss
    icon = "dialog-warning-symbolic"

# How to find the correct appname:
#   1. Trigger a notification from the app
#   2. Run:  dunstctl history
#   3. Look for "appname" in the output
#
# Filter fields available:
#   appname, desktop_entry, body, summary, category, icon,
#   msg_urgency (low|normal|critical), match_transient
#
# Actions:
#   skip_display = yes      ← block notification entirely
#   urgency = low           ← downgrade urgency
#   timeout = 0             ← make persistent
#   format = ""             ← hide text (icon-only)
#   set_transient = yes     ← allow timeout even when idle
#   history_ignore = yes    ← don't save in history
#   fullscreen = suppress   ← block in fullscreen
#

# ── opencode — show banner + play sound ──────────────────────────────
# Uses POSIX regex (enable_posix_regex = true in [global]):
#   "^Opencode"  matches summaries starting with "Opencode"
#   "Opencode"   matches any summary containing "Opencode"
[opencode_show]
    summary = "^Opencode"
    skip_display = no
    timeout = 8
    script = ~/.config/dunst/play-sound.bash

# ── Block examples (uncomment to use) ──

#[block_slack]
#    appname = "Slack"
#    skip_display = yes

#[block_discord]
#    appname = "Discord"
#    skip_display = yes

#[block_firefox]
#    appname = "Firefox"
#    skip_display = yes

#[block_chromium]
#    appname = "Chromium"
#    skip_display = yes

#[block_thunderbird_low]
#    appname = "Thunderbird"
#    msg_urgency = "low"
#    skip_display = yes

#[block_thunderbird_normal]
#    appname = "Thunderbird"
#    msg_urgency = "normal"
#    skip_display = yes

# ── Quiet examples ──

#[quiet_steam]
#    appname = "Steam"
#    urgency = "low"
#    timeout = 3

#[icon_only_volume]
#    appname = "pavucontrol"
#    format = ""
#    hide_text = yes

DUNSTRC

info "dunstrc written"

# ── Step 4: Tell Cinnamon to allow external notification handlers ────
header "Cinnamon: allow external notification handlers"

CURRENT=$(gsettings get org.cinnamon allow-other-notification-handlers)
if [[ "$CURRENT" == "false" ]]; then
    gsettings set org.cinnamon allow-other-notification-handlers true
    info "set allow-other-notification-handlers → true"
else
    info "already true"
fi

# ── Step 5: Handle systemd service ───────────────────────────────────
header "Systemd: enabling dunst.service"

# The dunst package installs /usr/lib/systemd/user/dunst.service with
# Type=dbus and BusName=org.freedesktop.Notifications, making it eligible
# for D-Bus activation. We use systemd --user for lifecycle management:
#   - Enable → auto-starts on login (graphical-session.target)
#   - D-Bus activation → starts on demand when any app sends a notification
#
# If dunst.service was previously masked (by a prior run of this script),
# unmask it first.
if systemctl --user --quiet is-active dunst 2>/dev/null; then
    info "stopping current dunst.service..."
    systemctl --user stop dunst 2>/dev/null || true
fi
if systemctl --user --quiet is-failed dunst 2>/dev/null; then
    systemctl --user reset-failed dunst 2>/dev/null || true
fi
if [[ "$(systemctl --user is-enabled dunst 2>/dev/null)" == "masked" ]]; then
    systemctl --user unmask dunst 2>/dev/null
    info "unmasked dunst.service"
fi
systemctl --user enable dunst 2>/dev/null
info "enabled dunst.service (systemd will manage lifecycle)"

# ── Step 6: Force Cinnamon to release the D-Bus name ────────────────
header "Taking over notification D-Bus service"

# On Cinnamon, the notification system is baked into the cinnamon process.
# Cinnamon holds the org.freedesktop.Notifications D-Bus name exclusively.
# Even with allow-other-notification-handlers=true, the CURRENT session
# won't release it — Cinnamon must restart to pick up the change.
#
# We restart Cinnamon in-place (cinnamon --replace). This is the same as
# pressing Alt+F2 → r → Enter. All running apps and windows are preserved.
info "restarting Cinnamon shell to release notification D-Bus name..."
echo "  (Your screen may flicker briefly — this is normal)"
setsid cinnamon --replace > /tmp/cinnamon-restart.log 2>&1 &

# Wait for Cinnamon to restart
sleep 5

# ── Step 7: Start dunst via systemd ───────────────────────────────────
header "Starting dunst via systemd"

# Now that Cinnamon has released the D-Bus name, start dunst.service.
# systemd will manage the process lifecycle and handle D-Bus activation.
info "starting dunst.service..."
systemctl --user start dunst 2>/dev/null
sleep 2

# ── Step 8: Verify ───────────────────────────────────────────────────
header "Verifying D-Bus name ownership"

OWNER=$(busctl --user list 2>/dev/null \
    | awk '/^org\.freedesktop\.Notifications/ {print $2}')

if [[ "$OWNER" == "dunst" ]]; then
    PID=$(busctl --user list 2>/dev/null \
        | awk '/^org\.freedesktop\.Notifications/ {print $3}')
    info "dunst owns org.freedesktop.Notifications (PID $PID)"
else
    err "Cinnamon still owns org.freedesktop.Notifications (owner: $OWNER)"
    err ""
    err "Try:  cinnamon --replace && systemctl --user restart dunst"
    err ""
    err "If that doesn't work, log out and back in to pick up changes."
    exit 1
fi

# ── Step 9: Test ─────────────────────────────────────────────────────
header "Testing"

echo -e "  Sending test notification..."
notify-send \
    --urgency=normal \
    --app-name="Opencode" \
    "Opencode" \
    "Permission requested: tool execution"

sleep 1
info "Notification sent (banner + sound expected)"

# ── Done ─────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}✔ Setup complete${NC}"
echo ""
echo "  Next steps:"
echo "    1. Trigger an opencode notification — you should see banner + hear sound"
echo "    2. To block an app, edit ~/.config/dunst/dunstrc, uncomment a rule"
echo "    3. Restart dunst:  systemctl --user restart dunst"
echo ""
echo "  Commands:"
echo "    systemctl --user status dunst   check dunst is running"
echo "    dunstctl history                show recent notifications with metadata"
echo "    dunstctl close                  close current notification"
echo "    dunstctl close-all              close all notifications"
echo "    dunstctl is-paused              check if notifications are paused"
echo "    dunstctl set-paused true        pause all notifications"
echo ""
echo "  File: ~/.config/dunst/dunstrc"
echo "  Note: dunst.service is enabled via systemd --user."
echo "        It starts automatically on login and via D-Bus activation."
echo ""
