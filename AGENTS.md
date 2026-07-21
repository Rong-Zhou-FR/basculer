# Basculer AGENTS.md

## Project Overview
Collection of productivity tweaks for Debian-based Linux. Users clone, customize, then symlink or source the components they need.

## Architecture
```
basculer/
├── opencode-config/    # opencode config — plugins & config
│   ├── AGENTS.md       # describes the opencode config layout
│   ├── opencode/       # config files — symlinked to ~/.config/opencode
│   └── .opencode/      # project-local plugins — auto-loaded by opencode
│       ├── plugins/    # plugin symlinks + kdco-primitives
│       ├── tests/      # plugin test files
│       └── opencode.jsonc  # plugin registration
├── super-bash/         # bash utility functions — source from ~/.bashrc
├── espanso/            # espanso match files — symlink to ~/.config/espanso
├── nvim/               # Neovim config — symlink to ~/.config/nvim
├── 0-1/                # Zero-to-One planning framework (standalone)
├── dev/                # development docs, plans, and templates
├── ZellijAlacritty/    # Alacritty+Zellij terminal stack — run install.sh
├── ronWorkspace/       # personal workspace launchers — run lighter-dev.bash
├── tests/              # standalone bash test suites
├── .serena/            # Serena AI project config (memories, cache)
├── AGENTS.md           # this file
├── README.md           # user-facing quick start
├── LICENSE
└── .gitignore
```

## Modules

| Module | Integration | Purpose |
|--------|-------------|---------|
| [opencode](./opencode-config/AGENTS.md) | symlink | Code assistant config (agents, context-mode, commands) |
| [super-bash](./super-bash/AGENTS.md) | source | Shell utility functions (dev, automation, text) |
| [espanso](./espanso/AGENTS.md) | symlink | Text expansion matches |
| [nvim](./nvim/AGENTS.md) | symlink | Neovim configuration (init.lua, plugins, ftplugin) |
| [0-1](./0-1/0.md) | standalone | Zero-to-One planning framework — problem/ideal/solution/eval |
| [ZellijAlacritty](./ZellijAlacritty/AGENTS.md) | run | Alacritty+Zellij terminal stack — install, configure, use |
| [ronWorkspace](./ronWorkspace/) | run | Personal workspace launchers (lighter-system development) |
| [dev](./dev/) | reference | Development plans, examples, templates |
| [.serena](./.serena/) | internal | AI assistant project config & memories |

### Module details

**opencode** — opencode IDE config (agents, commands, context-mode sessions, model configs, plugins). Two directories:
- Config files: `opencode-config/opencode/` — symlinked to `~/.config/opencode/`
- Project plugins: `opencode-config/.opencode/` — auto-loaded by opencode from project root

See [opencode-config/AGENTS.md](./opencode-config/AGENTS.md).

**super-bash** — pure-bash utility collections:
- `bash-dev.bash` — dev helpers (git, docker, etc.)
- `bash-autish.bash` — shell automation
- `bash-text-opt.bash` — text processing / optimisation
- `functions/` — additional modular function files:
  - `A-semantika-nodo-aldoni.bash` — semantic node wrappers
  - `A-semantika-arko-aldoni.bash` — semantic edge wrappers
  - `A-semantika-temp.bash` — template/boilerplate node creation
  - `A-semantika-predikato-aldoni-1.bash` — predicate creation wrapper
  - `A_enc_generi.bash` — encrypted agent wrapper
See [super-bash/AGENTS.md](./super-bash/AGENTS.md).

**espanso** — espanso text expansion match files:
- `match/` — active match definitions (YAML)
- `match-bak/` — archived / backup match files
- `config/` — espanso config (`default.yml`)
See [espanso/AGENTS.md](./espanso/AGENTS.md).

**nvim** — Neovim configuration:
- `init.lua` — entry point (options, keymaps, user commands, lazy.nvim setup)
- `lua/markdown.lua` — markdown utilities (comma-list-to-bullets `:CM` command)
- `after/ftplugin/enc.lua` — filetype overrides for `.enc` files
- `lazy-lock.json` — plugin lockfile (Comment.nvim, lazy.nvim)

**0-1** — Zero-to-One structured planning documents. Each document walks through: real-world problem → ideal state → concrete steps → evaluation with self & peer review.

**ZellijAlacritty** — Alacritty+Zellij terminal stack:
- `install.sh` — install/update Alacritty and Zellij binaries + configs
- `set-default.sh` — auto-start Zellij on every graphical terminal
- `ZellijAlacritty-101.md` — usage guide, keybindings, layouts, troubleshooting

**ronWorkspace** — Personal workspace launchers:
- `lighter-dev.bash` — launch lighter-system dev workspace (Alacritty+Zellij across virtual desktops)
  - Uses `opencode serve` daemon + `opencode attach` per-tab to share one Bun/Node.js
    runtime across all opencode sessions (~3-4x memory reduction vs N independent servers)
  - Gitmaster tabs use `opencode run --attach --agent gitmaster --mini` (interactive split-footer)
  - Configurable via `OPCODE_SERVE_PORT` (default 4096)
- `tests/test_lighter_dev.bats` — standalone bash test suite for lighter-dev.bash

**.serena** — Serena AI project configuration:
- `memories/` — per‑module memories (opencode/, super-bash/, espanso/, naming-conventions/, config/)
- `project.yml` — project metadata

## Quick Start
```bash
# Clone
git clone https://github.com/yourname/basculer.git ~/.basculer

# opencode (symlink)
ln -sf ~/.basculer/opencode-config/opencode ~/.config/opencode

# bash (source in ~/.bashrc)
echo "source ~/.basculer/super-bash/bash-dev.bash" >> ~/.bashrc
echo "source ~/.basculer/super-bash/bash-autish.bash" >> ~/.bashrc

# espanso (symlink)
espanso stop
ln -sf ~/.basculer/espanso ~/.config/espanso
espanso start

# neovim (symlink)
# IMPORTANT: Only symlink if starting fresh or backup existing ~/.config/nvim first
ln -sf ~/.basculer/nvim ~/.config/nvim
```

## Important Notes

### Stop Apps Before Symlinking Config Folders
Some apps (like espanso) will auto-recreate their config folder on startup if you delete it. To properly symlink:
```bash
# 1. Stop the app
espanso stop

# 2. Remove/rename original config folder
rm -rf ~/.config/espanso

# 3. Create symlink
ln -sf ~/.basculer/espanso ~/.config/espanso

# 4. Restart the app
espanso start
```
