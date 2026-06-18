# Basculer

Collection of productivity tweaks for Debian-based Linux.

## Quick Start

```bash
# 1. Clone
git clone https://github.com/yourname/basculer.git ~/.basculer

# 2. opencode — symlink
ln -sf ~/.basculer/opencode ~/.config/opencode

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
| `opencode/` | symlink | opencode IDE config |
| `super-bash/` | source | Bash utility functions |
| `espanso/` | symlink | Text expansion matches |
| `nvim/` | symlink | Neovim config |
| `0-1/` | standalone | Zero-to-One planning framework |
| `dev/` | reference | Development docs & templates |

## Notes

- **Stop apps before symlinking config folders.** Some apps (espanso) auto-recreate their config on startup. Always stop → remove original → symlink → restart.
- **nvim:** Only symlink `~/.config/nvim` if starting fresh. Backup your existing config first.
- **bash:** Source only the files you need — each file is independent.
