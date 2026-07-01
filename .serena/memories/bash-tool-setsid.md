# Bash Tool Timeout — Using `setsid` for Long-Running Processes

The bash tool kills its shell session (and all child processes) when the command timeout expires.

## What doesn't survive a timeout

- `command &` — child dies with parent shell
- `nohup command &` — fails when the shell session is killed
- `cmd & ; sleep ; curl` — `&` is in a subshell; children go with it

## What works

### Primary: `setsid`

```bash
setsid npx nuxt dev --port 3000 --host 0.0.0.0 > /tmp/nuxt-dev.log 2>&1 &
```

`setsid` creates a new session that survives the parent shell's death. The only way it dies is an explicit `kill`.

### Alternative: `screen` / `tmux`

```bash
screen -dmS <name> <command>
```

But these may not be installed in all environments.

### Fallback: use production build directly

If a project is already built (e.g., `nuxt build` succeeded), skip the dev server entirely:

```bash
setsid node .output/server/index.mjs > /tmp/nuxt-preview.log 2>&1 &
```

This avoids watch-mode overhead and is faster for browser testing.

See `opencode/AGENTS.md` (Command Execution section) for the canonical reference.
