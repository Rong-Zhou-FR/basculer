# Zellij + Alacritty 101

**Alacritty** is a fast, GPU-accelerated terminal emulator.
**Zellij** is a terminal multiplexer (like tmux/screen) — it manages multiple panes, tabs, and persistent sessions inside a single terminal window.

Together they give you a lightweight, keyboard-driven development environment.

---

## Table of Contents

- [1. Installation](#1-installation)
- [2. Launching](#2-launching)
- [3. How They Work Together](#3-how-they-work-together)
  - [3.1 The Stack](#31-the-stack)
  - [3.2 Mental Model: Alacritty is the Window, Zellij is the Desktop](#32-mental-model-alacritty-is-the-window-zellij-is-the-desktop)
  - [3.3 Daily Workflow](#33-daily-workflow)
  - [3.4 Zellij Keybindings](#34-zellij-keybindings)
  - [3.5 Persistent Sessions](#35-persistent-sessions)
  - [3.6 Layouts](#36-layouts)
  - [3.7 Tips & Troubleshooting](#37-tips--troubleshooting)

---

## 1. Installation

### One-shot

```bash
# From the basculer root:
./ZellijAlacritty/install.sh
```

This does everything:

| Step | What happens | Skip-if |
|------|-------------|---------|
| Alacritty binary | `apt install alacritty` | Already on `$PATH` |
| Alacritty config | Writes `~/.config/alacritty/alacritty.toml` | File already exists |
| Zellij binary | Downloads `zellij-x86_64-unknown-linux-musl.tar.gz` from GitHub, installs to `/usr/local/bin` | Already on `$PATH` |
| Zellij config | Writes `~/.config/zellij/config.kdl` | File already exists |

You'll be prompted for `sudo` once at the start — it's cached for the rest of the script.

### Config only

If the binaries are already handled by your distro:

```bash
./ZellijAlacritty/install.sh --config
```

This skips all binary checks and just writes the config files.

### Manual config locations

| Config file | Purpose |
|-------------|---------|
| `~/.config/alacritty/alacritty.toml` | Font, colours, padding, keybinds, opacity |
| `~/.config/zellij/config.kdl` | Theme, pane frames, keybinding overrides |

Edit these to customise. The script won't overwrite them if they already exist — delete a file and re-run `--config` to regenerate it.

---

## 2. Launching

### Start Alacritty

```bash
alacritty &
```

Or launch it from your application menu / launcher (look for "Alacritty").

To make it your **default terminal emulator**:

```bash
sudo update-alternatives --config x-terminal-emulator
# Select the number for alacritty
```

After this, Ctrl+Alt+T and other apps that spawn a terminal will open Alacritty.

### Start Zellij inside Alacritty

Inside Alacritty, just run:

```bash
zellij
```

Zellij takes over the terminal window and shows its UI — a status bar at the bottom, pane borders, and a tab bar at the top.

### Auto-start Zellij on every shell (optional)

The `set-default.sh` script adds this to `~/.bashrc` automatically:

```bash
# Auto-start Zellij inside graphical terminals
# (not SSH sessions, not TTY consoles, not pipes).
if [[ -z "$ZELLIJ" && -z "$SSH_TTY" && "$TERM" != "dumb" && "$(tty)" != /dev/tty* ]]; then
    zellij
fi
```

Each terminal window gets its **own** Zellij session. To re-attach a previous session later, use `zellij attach <session-name>` manually — see [Persistent Sessions](#35-persistent-sessions).

This only starts Zellij in graphical terminal windows (not SSH, not TTY consoles). The `$ZELLIJ` check prevents infinite recursion if you run `bash` inside a Zellij pane.

---

## 3. How They Work Together

### 3.1 The Stack

```
┌─────────────────────────────────────────┐
│            Your OS (Linux)              │
│  ┌───────────────────────────────────┐  │
│  │         Alacritty (window)        │  │
│  │  ┌─────────────────────────────┐  │  │
│  │  │     Zellij (multiplexer)    │  │  │
│  │  │  ┌──────┐  ┌──────┐        │  │  │
│  │  │  │ nvim  │  │ bash │  tab1 │  │  │
│  │  │  └──────┘  └──────┘        │  │  │
│  │  │  ┌──────────────────────┐  │  │  │
│  │  │  │      lazygit         │  │  │  │
│  │  │  └──────────────────────┘  │  │  │
│  │  │              tab2          │  │  │
│  │  └─────────────────────────────┘  │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

Each layer has one job:

| Layer | Job | Analogous to |
|-------|-----|-------------|
| **Alacritty** | Renders text fast (GPU), handles windowing, font, colours | Your monitor |
| **Zellij** | Manages terminal "real estate" — splits, tabs, sessions | Your desktop environment |

### 3.2 Mental Model: Alacritty is the Window, Zellij is the Desktop

- **Alacritty** is just the frame. It draws text on screen, handles copy/paste, and manages the window. It has no concept of tabs, splits, or sessions.
- **Zellij** is the workspace manager inside that frame. It creates panes (splits), tabs, and lets you detach/re-attach sessions — similar to what a tiling window manager does for GUI windows, but for terminals.

You could use Alacritty alone (just a plain shell), or Zellij inside any other terminal (gnome-terminal, kitty, etc.). But together:

- Alacritty gives you **speed** (GPU rendering, low latency) and **consistency** (same look across all machines via `alacritty.toml`)
- Zellij gives you **productivity** (splits, tabs, sessions, a status bar, pane management)

### 3.3 Daily Workflow

Here's a typical development session:

#### Start

```bash
# Open Alacritty (from launcher or Ctrl+Alt+T)
# Inside, Zellij auto-starts (if you set up ~/.bashrc as above)
# Or manually:
zellij
```

#### What you see

```
┌─────────────────────────────────────────┐
│ tab: main                          1/1  │
├─────────────────────────────────────────┤
│                                         │
│     $ _  (cursor here, one big pane)    │
│                                         │
│                                         │
├─────────────────────────────────────────┤
│          NORMAL  |  main                │
└─────────────────────────────────────────┘
```

Zellij starts with one full-screen pane — a shell. The **status bar** at the bottom shows the current mode (`NORMAL`) and tab name.

#### Split terminal into two panes

Press `Ctrl p` then `d` (split down):

```
┌─────────────────────────────────────────┐
│ tab: main                          1/1  │
├─────────────────────────────────────────┤
│  pane 1                          │ pane │
│  $ cd project                     │ 2    │
│  $ ls                             │ $ _  │
│  src/  dist/  tests/              │      │
├─────────────────────────────────────────┤
│          NORMAL  |  main                │
└─────────────────────────────────────────┘
```

- `Ctrl p` enters **pane mode** (notice the status bar changes)
- `d` = split down
- `r` = split right
- `n` = new pane (opens in the direction of the last split)
- `x` = close focused pane
- `Tab` / arrow keys = move focus between panes

#### Add a tab

Press `Ctrl t` then `n`:

```
┌─────────────────────────────────────────┐
│ tab: main  |  tab: logs*    tabs  1/2  │
├─────────────────────────────────────────┤
│                                         │
│     $ journalctl -f                     │
│     Jul 14 15:30:01 ...                 │
│                                         │
├─────────────────────────────────────────┤
│          NORMAL  |  logs                │
└─────────────────────────────────────────┘
```

- `Ctrl t` enters **tab mode**
- `n` = new tab
- `Tab` / arrows = switch tabs
- `x` = close tab

#### Detach and re-attach (persistent session)

| Action | Command |
|--------|---------|
| Detach | `Ctrl o` then `d` |
| Re-attach | `zellij attach` |
| List sessions | `zellij list-sessions` |
| Attach by name | `zellij attach <session-name>` |

Your session (all panes, tabs, cwd) survives even after you close Alacritty. This is useful for:
- Long-running processes (builds, servers)
- SSH: connect, `zellij attach`, disconnect, reconnect later
- Network drops: just re-attach

#### Scratchpad (floating pane)

Press `Ctrl p` then `w` to toggle a floating pane on top of your layout — useful for a quick command without splitting.

#### Rename tab

Press `Ctrl t` then `c` to rename the current tab (e.g. `logs` → `server`).

### 3.4 Zellij Keybindings

Zellij is modal (like vim). The default modes:

| Mode | Enter | Purpose |
|------|-------|---------|
| **Normal** | `Ctrl g` | Default — arrow keys navigate panes |
| **Pane** | `Ctrl p` | Split, close, move, resize panes |
| **Tab** | `Ctrl t` | Create, switch, close tabs |
| **Resize** | `Ctrl n` | Resize the focused pane |
| **Move** | `Ctrl p` then hold `Shift` + arrows | Move panes around |
| **Scroll** | `Ctrl s` | Scroll pane history, search |
| **Session** | `Ctrl o` | Detach, rename session, toggle UI |

#### Common shortcuts cheat sheet

| Shortcut | Action |
|----------|--------|
| `Ctrl p` `d` | Split pane down |
| `Ctrl p` `r` | Split pane right |
| `Ctrl p` `x` | Close pane |
| `Ctrl p` `w` | Toggle floating pane |
| `Ctrl p` `f` | Toggle fullscreen for pane |
| `Ctrl p` `z` | Toggle pane frames |
| `Ctrl t` `n` | New tab |
| `Ctrl t` `x` | Close tab |
| `Ctrl t` `<number>` | Go to tab N |
| `Ctrl g` | Back to normal mode |
| `Ctrl s` | Enter scroll mode, then `j`/`k` to scroll, `/` to search |
| `Ctrl o` `d` | Detach session |

### 3.5 Persistent Sessions

Zellij sessions survive **terminal closure** (close the window, re-attach later) and **suspend/resume** (laptop lid close). They do **not** survive a **machine reboot** — the Zellij daemon and all its processes die on shutdown.

Typical daily pattern:

```bash
# Morning
zellij

# In pane 1: nvim
# In pane 2: npm run dev
# In tab 2: journalctl -f

# Evening — detach (Ctrl o d), lock the machine
# Next morning — re-attach by session name
zellij attach project-api
```

**Named sessions** 

```bash
zellij -s project-api      # start a new session named project-api; -s = --session 
zellij attach project-api          # re-attach to an existing one
```

This is useful for **project isolation** — each project gets its own named session with its own tabs, panes, and scrollback. You can keep a `dev` session for coding, a `logs` session for monitoring, etc.

List all running sessions:

```bash
zellij list-sessions
```

Attach to a session by name (unique prefix works too):

```bash
zellij attach dev
zellij attach lo                  # attaches to "logs" if no other session starts with "lo"
```

Or kill a session (terminates **all processes** inside its panes):

```bash
zellij kill-session project-web
```

> **`kill-session` vs `detach`**: `kill-session` terminates every process in that session (editors, servers, builds — all gone). `detach` (`Ctrl o` `d`) leaves everything running so you can `zellij attach` later.

Each session has its own tabs and panes.

#### Sessions and reboots

If your machine restarts, all Zellij sessions are **lost** — the daemon and every process inside the panes are killed. To get back to work quickly:

1. If you previously saved a **layout dump** (see [3.6 Layouts](#36-layouts)), restore it:
   ```bash
   zellij -s project-api --layout ~/.config/zellij/layouts/dev.kdl
   ```
2. If you didn't save a layout, you'll need to re-create splits and re-launch commands manually.

Tip: after setting up a useful pane/tab arrangement, dump the layout for next time:

```bash
zellij --layout-dump > ~/.config/zellij/layouts/project-api.kdl
```

This captures the pane sizes, splits, tabs, and any explicit `command` settings — but **not** the working directory of each pane, nor the commands currently running inside them. After a reboot you get the same pane geometry back, but each pane starts from `$HOME` (or wherever you launched `zellij`).

> **Full restore?** No — there is no tmux-resurrect equivalent for Zellij. Sessions are entirely in-memory. To approximate it: use layouts with `command`/`args` to re-launch your tools, and rely on editor recovery files (nvim's `:shada`, vscode's workspace restore) for unsaved work.
>
> **Cinnamon session restore**: Mint's System Settings → General → "Automatically remember running applications when logging out" restarts GUI apps that were open, but it does **not** restore terminal programs running inside Zellij.
>
> **Autostart workaround**: Create a `.desktop` file in `~/.config/autostart/` to launch Alacritty + Zellij with your layout on login:
> ```bash
> mkdir -p ~/.config/autostart
> cat > ~/.config/autostart/zellij-dev.desktop << 'EOF'
> [Desktop Entry]
> Type=Application
> Name=Zellij Dev Session
> Exec=alacritty -e zellij -s dev --layout ~/.config/zellij/layouts/dev.kdl
> X-Cinnamon-Autostart-enabled=true
> EOF
> ```
> This opens an Alacritty window running Zellij with your layout automatically after login.
>
> **Real-world example**: Say you always start your day with a `project-api` session (split: nvim left, terminal right) and a `logs` session (journalctl). You'd create two layouts and two autostart entries. After reboot: both Alacritty windows pop open, each running Zellij with the right splits already in the right directories — you just pick up where the panes left off.
>
> Add one `.desktop` per named session you want restored.

### 3.6 Layouts

Zellij can restore a predefined pane layout from a file. This is useful for projects that always need the same split.

Save a layout at `~/.config/zellij/layouts/dev.kdl`:

```kdl
layout {
    pane size=1 borderless=true {
        plugin location="tab-bar"
    }
    pane split_direction="vertical" {
        pane size="40%" {
            // opens nvim if available
        }
        pane split_direction="horizontal" {
            pane size="50%" {
                // terminal
            }
            pane {
                // terminal
            }
        }
    }
    pane size=2 borderless=true {
        plugin location="status-bar"
    }
}
```

Then launch with:

```bash
zellij --layout dev
zellij -s project-api --layout dev   # with a named session
```

**Per-pane startup commands**: Each pane can run a command on start:

```kdl
pane command="htop" size="50%"
pane command="bash" args=["-c", "cd ~/project && exec nvim"]
```

The `exec` is important — it replaces the shell so the pane exits cleanly when you close nvim. For a terminal pane that starts in a specific directory:

```kdl
pane command="bash" args=["-c", "cd ~/project && exec bash"]
```

> **Note**: Layouts have no native `cwd` attribute — you must wrap directory changes in a shell command as shown above.

You can also capture your current layout:

```bash
zellij --layout-dump > ~/.config/zellij/layouts/current.kdl
```

### 3.7 Tips & Troubleshooting

#### Alacritty

| Symptom | Fix |
|---------|-----|
| Font too small | `Ctrl` + `=` / `Ctrl` + `-` to adjust live |
| Can't copy/paste | `Ctrl+Shift+C` / `Ctrl+Shift+V` |
| Window too transparent | Edit `window.opacity` in `alacritty.toml` (0.0–1.0) |
| Slow startup | Alacritty compiles shaders on first launch — subsequent launches are near-instant |

#### Zellij

| Symptom | Fix |
|---------|-----|
| `Failed to parse configuration` | Check `~/.config/zellij/config.kdl` for syntax errors. Zellij uses KDL — keys are single strings: `unbind "Ctrl q"`, not `unbind "Ctrl" "q"`. |
| Plugin errors | Zellij downloads plugins on first run. If offline, it may show errors — they're cached after the first successful download. |
| Scrollback lost after re-attach | Scroll history persists per session. If it's lost, you may have attached to a new session instead of the old one. Use `zellij list-sessions` to check. |
| Pane not responding | You may be in a mode. Press `Ctrl g` to return to Normal mode. |
| Accidentally closed a pane | Content is gone (no undo for panes). Use `Ctrl p` `w` (floating pane) for scratch work you might discard. |

#### Alacritty + Zellij interaction

| Situation | What happens |
|-----------|-------------|
| You close the Alacritty window | Zellij session **detaches** (not killed). Re-attach later with `zellij attach`. |
| You press `Ctrl+Shift+C` in Alacritty | Copies selection to clipboard — Zellij's clipboard is independent, so this works even in Zellij pane mode. |
| You want to paste into Zellij | Use `Ctrl+Shift+V` (Alacritty paste) or middle-click. Inside Zellij, `Ctrl s` (scroll mode) + `p` pastes from Zellij's internal buffer. |
| Alacritty window too small for layout | Zellij handles this gracefully — panes become scrollable or hide. Resize the window and Zellij re-lays out automatically. |

---

*The `alacritty.toml` and `config.kdl` files created by `install.sh` are minimal starting points. Refer to the official docs for full configuration options:*

- [Alacritty config](https://alacritty.org/config-alacritty.html)
- [Zellij config](https://zellij.dev/documentation/configuration.html)
