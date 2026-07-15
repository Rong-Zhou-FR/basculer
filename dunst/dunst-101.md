# dunst-101 — Per-App Notification Filtering with Dunst

## What & Why

[Dunst](https://dunst-project.org/) is a lightweight notification daemon that replaces Cinnamon's built-in notification system. Cinnamon (≤ v6.4) only offers a **global** notification toggle — you can't block or customise notifications per application.

With dunst you can:

- **Block** notifications from specific apps entirely
- **Downgrade** urgency (e.g., Steam → low)
- **Route** to a different monitor
- **Play a sound** for specific apps
- **Persist** notifications (never timeout) for critical apps
- **Icon-only mode** for volume/brightness changes

---

## Quick Start

If you haven't set up dunst yet:

```bash
bash path/to/basculer/dunst/dunst-install.bash
```

This installs dunst, writes a config with an opencode rule already active, masks the systemd service, restarts Cinnamon, and verifies dunst owns the D-Bus notification name.

---

## Finding the Correct Filter Values

Every notification has attributes you can filter on:

| Attribute    | What it matches                                 |
|--------------|-------------------------------------------------|
| `appname`    | Application name (e.g. `"Slack"`, `"firefox"`)  |
| `desktop_entry` | Desktop entry name (e.g. `"org.mozilla.firefox"`) – more stable than appname |
| `summary`    | Notification title                              |
| `body`       | Notification body text                          |
| `category`   | Category per [freedesktop spec](https://specifications.freedesktop.org/notification-spec/latest/categories.html) |
| `msg_urgency`| `"low"`, `"normal"`, or `"critical"`            |
| `icon`       | Icon path                                       |

### Method 1: `dunstctl history` (easiest)

1. Trigger a notification from the target app.
2. Run:
   ```bash
   dunstctl history
   ```
3. Look for `"appname"` in the JSON output — that's the value to use in your rule.

### Method 2: Monitor with `dbus-monitor`

For apps that send notifications before dunst starts (or if history is empty):

```bash
dbus-monitor --session "interface=org.freedesktop.Notifications" |
  grep -E "string " | head -10
```

Trigger a notification and you'll see the app name in the output.

### Known appnames for common apps

| App | `appname` value(s) | Notes |
|-----|-------------------|-------|
| Slack | `Slack` | |
| Discord | `Discord` | |
| Firefox | `Firefox` | |
| Chromium/Chrome | `Chromium` / `Chromium-browser` / `google-chrome` | Varies by distro |
| Thunderbird | `Thunderbird` | |
| Spotify | `Spotify` | |
| Steam | `Steam` | |
| Telegram | `TelegramDesktop` | |
| Signal | `signal` | |
| opencode | _(none set)_ | Use `summary = "^Opencode"` (POSIX regex) instead |
| `notify-send` (default) | `notify-send` | When no `--app-name` is passed |

---

## Rule Syntax

Rules live in `~/.config/dunst/dunstrc` as INI sections. A rule can have **filters** (what to match) and **modifiers** (what to do).

### Minimal block rule

```ini
[block_slack]
    appname = "Slack"
    skip_display = yes
```

### Rule with multiple filters (AND logic)

```ini
[thunderbird_low_only]
    appname = "Thunderbird"
    msg_urgency = "critical"
    # Only critical Thunderbird notifications shown; low + normal are blocked
    # by separate rules (order matters — put more specific rules first)
```

### Rule with rich modifiers

```ini
[opencode_show]
    summary = "^Opencode"          # POSIX regex — matches "Opencode" at start
    skip_display = no              # show the banner (default, explicit for clarity)
    timeout = 8                    # seconds until auto-dismiss
    script = ~/.config/dunst/play-sound.bash
    urgency = normal
```

### Match anything (catch-all/global)

Rules in the `[global]` section have no filters and apply to every notification. Urgency sections (`[urgency_low]`, `[urgency_normal]`, `[urgency_critical]`) also apply to all notifications of that urgency.

---

## Glob vs Regex

By default dunst uses **globbing** (`fnmatch`):

```ini
appname = "firefox*"      # glob — matches "firefox", "firefox-esr", etc.
```

With `enable_posix_regex = true` in `[global]` (recommended, and already set in the install script's template), you get **POSIX extended regular expressions**:

```ini
appname = "^firefox"      # regex — matches "firefox" at start of string
summary = "Opencode"      # regex — matches any summary CONTAINING "Opencode"
summary = "^Opencode"     # regex — matches summary STARTING WITH "Opencode"
```

**Key differences:**

| Pattern | Glob meaning | Regex meaning |
|---------|-------------|--------------|
| `*` | any characters | _(literal asterisk)_ |
| `.*` | literal `.*` | any characters |
| `foo` | `foo` exactly | `foo` anywhere (substring match) |
| `"foo"` | literal `"foo"` | literal `"foo"` |

With the config's `enable_posix_regex = true`, you almost always want to anchor with `^` for appname/summary matching, or use `.*` for "contains" matching:

```ini
summary = "error"          # matches "fatal error", "ErrorHandler", etc. (case-sensitive)
appname = "^Slack$"        # matches exactly "Slack"
```

---

## Common Recipes

### Block an app entirely

```ini
[block_discord]
    appname = "Discord"
    skip_display = yes
    history_ignore = yes     # don't even save it
```

### Only show critical, hide low/normal

```ini
[thunderbird_low]
    appname = "Thunderbird"
    msg_urgency = "low"
    skip_display = yes

[thunderbird_normal]
    appname = "Thunderbird"
    msg_urgency = "normal"
    skip_display = yes
```

### Downgrade an app's urgency

```ini
[steam_quiet]
    appname = "Steam"
    urgency = "low"
    timeout = 3
```

### Make critical notifications persistent

```ini
# In [urgency_critical] section override, or per-app:
[my_monitor]
    appname = "uptime-monitor"
    timeout = 0               # never dismiss
    urgency = critical
```

### Icon-only (hide text)

```ini
[volume_icon]
    appname = "pavucontrol"
    format = ""
    hide_text = yes
```

### Play a sound for specific notifications

Create a script (see `~/.config/dunst/play-sound.bash` from the install script):

```bash
#!/bin/bash
canberra-gtk-play --id="desktop-notification" 2>/dev/null ||
    paplay /usr/share/mint-artwork/sounds/notification.oga 2>/dev/null
```

Reference it in a rule:

```ini
[opencode_sound]
    summary = "^Opencode"
    script = ~/.config/dunst/play-sound.bash
```

---

## Commands Reference

| Command | What it does |
|---------|-------------|
| `dunstctl history` | Show recent notifications as JSON (includes appname, summary, etc.) |
| `dunstctl close` | Close the current notification |
| `dunstctl close-all` | Close all visible notifications |
| `dunstctl history-pop` | Re-display the last dismissed notification |
| `dunstctl is-paused` | Check if paused (`true`/`false`) |
| `dunstctl set-paused true` | Pause all notifications |
| `dunstctl rule <name> enable` | Enable a rule by section name |
| `dunstctl rule <name> disable` | Disable a rule by section name |
| `notify-send "title" "body"` | Send a test notification |

There is no `dunstctl reload` in v1.9.x. To reload config:

```bash
pkill -u "$USER" dunst
setsid /usr/bin/dunst &
```

---

## Restarting Dunst

```bash
# 1. Kill (your dunst only, not root-owned zombies)
pkill -u "$USER" dunst

# 2. Start
setsid /usr/bin/dunst &
```

If systemd keeps respawning dunst (stale service):

```bash
systemctl --user mask dunst     # prevent systemd from managing dunst
pkill -u "$USER" dunst
setsid /usr/bin/dunst &
```

---

## Files

| Path | Purpose |
|------|---------|
| `~/.config/dunst/dunstrc` | Main configuration |
| `~/.config/dunst/play-sound.bash` | Sound script (created by installer) |
| `/usr/bin/dunst` | The daemon binary |
| `/usr/bin/dunstctl` | Control CLI |
| `/usr/bin/dunstify` | Like `notify-send` but richer (supports actions, hints) |

---

## Troubleshooting

### Notifications still appear through Cinnamon, not dunst

Cinnamon still owns `org.freedesktop.Notifications` on D-Bus:

```bash
busctl --user list | grep org.freedesktop.Notifications
```

If the owner is `cinnamon` (not `dunst`), restart the shell:

```bash
setsid cinnamon --replace &
sleep 5
setsid /usr/bin/dunst &
```

Then verify again.

### Dunst can't claim the D-Bus name

```bash
systemctl --user mask dunst    # stop systemd interference
pkill -u "$USER" dunst
setsid /usr/bin/dunst &
```

### Config not taking effect

Kill and restart — dunst v1.9.x does not support `dunstctl reload`:

```bash
pkill -u "$USER" dunst; setsid /usr/bin/dunst &
```

### No sound

Check the script runs standalone:

```bash
bash ~/.config/dunst/play-sound.bash
```

If it returns 1, `canberra-gtk-play` and `paplay` are missing. Install:

```bash
sudo apt install libcanberra-gtk3-module pulseaudio-utils
```
