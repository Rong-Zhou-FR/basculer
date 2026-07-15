# Alacritty TOML Configuration Reference

Alacritty 0.13+ uses TOML for configuration (migrated from YAML).

## Global keys

```toml
[general]
live_config_reload = true
shell = { program = "/bin/zsh", args = ["-l"] }
```

## [env] — Environment variables

```toml
[env]
TERM = "alacritty"
WINIT_X11_SCALE_FACTOR = "1.0"
```

## [window] — Window settings

```toml
[window]
padding = { x = 3, y = 3 }
dynamic_padding = true
opacity = 0.9
decorations = "full"
```

## [scrolling] — Scrollback

```toml
[scrolling]
history = 10000
```

## [font] — Font configuration

Uses section headers for variants:

```toml
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
```

## [colors] — Color scheme

```toml
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
```

## [cursor] — Cursor style

```toml
[cursor]
style = "Block"
```

## [selection] — Selection behavior

```toml
[selection]
semantic_escape_chars = ",│`|:\"' ()[]{}<>"
```

## [keyboard] — Key bindings

Note: uses `[keyboard]` section with a `bindings` array (not `key_bindings` top-level key):

```toml
[keyboard]
bindings = [
    { key = "V",         mods = "Control|Shift", action = "Paste" },
    { key = "C",         mods = "Control|Shift", action = "Copy" },
    { key = "Key0",      mods = "Control",       action = "ResetFontSize" },
    { key = "Equals",    mods = "Control",       action = "IncreaseFontSize" },
    { key = "Minus",     mods = "Control",       action = "DecreaseFontSize" },
]
```

Source: https://alacritty.org/config-alacritty.html
