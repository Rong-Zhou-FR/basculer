## Issue: Apps recreate config folders on deletion

### Problem
When trying to symlink `~/.basculer/espanso` to `~/.config/espanso`, the folder got nested (espanso/espanso/).

### Root Cause
Espanso auto-recreated its config folder at `~/.config/espanso/` on startup, even after I removed it to make way for the symlink.

### Solution
Stop the relevant app before deleting its config folder:
```bash
# Stop espanso
espanso stop

# Then remove/rename the config folder
rm -rf ~/.config/espanso

# Create symlink
ln -sf ~/.basculer/espanso ~/.config/espanso

# Restart espanso
espanso start
```

### Apps known to do this
- espanso
- (likely others - test per case)