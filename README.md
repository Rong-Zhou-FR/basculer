# Basculer

Collection of productivity tweaks for Debian-based Linux.

## Quick Start

```bash
# 1. Clone
git clone https://github.com/yourname/basculer.git ~/.basculer

# 2. opencode — symlink config directory
ln -sf ~/.basculer/opencode-config/opencode ~/.config/opencode

# 3. bash — source in ~/.bashrc
echo "source ~/.basculer/super-bash/bash-dev.bash" >> ~/.bashrc
echo "source ~/.basculer/super-bash/bash-autish.bash" >> ~/.bashrc

# 4. espanso — stop then symlink
espanso stop
ln -sf ~/.basculer/espanso ~/.config/espanso
espanso start

# 5. neovim — symlink (backup existing config first!)
ln -sf ~/.basculer/nvim ~/.config/nvim
```

## Modules

| Module | Integration | Purpose |
|--------|-------------|---------|
| `opencode/` | symlink | opencode IDE config (AI assistant, MCP servers, plugins) |
| `super-bash/` | source | Bash utility functions |
| `espanso/` | symlink | Text expansion matches |
| `nvim/` | symlink | Neovim config |
| `ZellijAlacritty/` | run | Alacritty+Zellij terminal stack — install, configure, use |
| `ronWorkspace/` | run | Personal workspace launchers (lighter-system development) |
| `0-1/` | standalone | Zero-to-One planning framework |
| `dev/` | reference | Development docs & templates |

### Code Intelligence

Uses [Gortex](https://github.com/zzet/gortex) — a single-binary Go daemon with tree-sitter based indexing for all repos in the lighter-dev workspace. ~64 MiB for 7 repos vs serena's ~4.2 GB. See [opencode-config docs](./opencode-config/AGENTS.md#mcp-lifecycle-strategy) for details.

## Notes

- **Stop apps before symlinking config folders.** Some apps (espanso) auto-recreate their config on startup. Always stop → remove original → symlink → restart.
- **nvim:** Only symlink `~/.config/nvim` if starting fresh. Backup your existing config first.
- **bash:** Source only the files you need — each file is independent.
