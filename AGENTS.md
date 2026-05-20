# Basculer AGENTS.md

## Project Overview
Collection of productivity tweaks for Debian-based Linux. Users clone, customize, then symlink or source the components they need.

## Architecture
```
basculer/
├── opencode/       # opencode config (symlink)
├── super-bash/     # bash utility functions (source)
├── espanso/        # espanso match yml (symlink)
└── dev/           # development docs
```

## Modules

| Module | Integration | Purpose |
|--------|-------------|---------|
| [opencode](./opencode/AGENTS.md) | symlink | Code assistant config |
| [super-bash](./super-bash/AGENTS.md) | source | Shell utility functions |
| [espanso](./espanso/AGENTS.md) | symlink | Text expansion matches |

## Quick Start
```bash
# Clone
git clone https://github.com/yourname/basculer.git ~/.basculer

# opencode (symlink)
ln -sf ~/.basculer/opencode ~/.config/opencode

# bash (source in ~/.bashrc)
echo "source ~/.basculer/super-bash/bash-dev.bash" >> ~/.bashrc

# espanso (symlink)
# IMPORTANT: Stop espanso first before symlinking!
espanso stop
ln -sf ~/.basculer/espanso ~/.config/espanso
espanso start
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