# Cinnamon Workspaces Configuration

## Increase number of workspaces

```bash
# Disable dynamic workspaces (auto-create/destroy)
gsettings set org.cinnamon.muffin dynamic-workspaces false

# Set fixed number (up to 36)
gsettings set org.cinnamon.desktop.wm.preferences num-workspaces 8
gsettings set org.gnome.desktop.wm.preferences num-workspaces 8
gsettings set org.cinnamon number-workspaces 8
```

Restart Cinnamon: `cinnamon --replace &`

## Add keyboard shortcuts for workspaces 5+

Cinnamon only sets keybindings for workspaces 1-4 by default. Enable 5-8:

```bash
for i in 5 6 7 8; do
  gsettings set org.cinnamon.desktop.keybindings.wm "switch-to-workspace-$i" "['<Primary><Alt>$i']"
done
```

Pattern: `<Primary>` = Ctrl, `<Alt>` = Alt. Works up to workspace 12.

## Expo view (all workspaces grid)

- **`Super+S`** — hardcoded Expo shortcut
- **Hot corner**: enable via System Settings → Hot Corners, or:
  ```bash
  gsettings set org.cinnamon hotcorner-layout "['expo:true:0', 'scale:false:0', 'scale:false:0', 'desktop:false:0']"
  ```
- **Touchpad**: 3-finger swipe up (`org.cinnamon.gestures swipe-up-3`)
- **`Ctrl+Alt+↑`** — workspace switcher popup (shows all workspace thumbnails)

## Checking current values

```bash
gsettings get org.cinnamon.number-workspaces  # may not exist, try desktop.wm.prefs
gsettings get org.cinnamon.desktop.wm.preferences num-workspaces
gsettings get org.cinnamon.muffin dynamic-workspaces
gsettings list-recursively org.cinnamon.desktop.keybindings.wm | grep workspace
```
