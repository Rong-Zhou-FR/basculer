# Browser Plugin Hang Root Cause & Fix

## Problem
The opencode-browser-plugin (v1.0.1) hangs on ALL actions when a previous session was interrupted while the browser was active. The tool never returns from `chromium.launchPersistentContext()` or any operation targeting a dead context.

## Root Cause
1. **Plugin state in long-lived server process**: The module-level `state` object (containing `context`, `pages`, `pageCounter`) persists in the opencode server process across ALL client sessions. When a client session disconnects, the Chromium process and `state.context` remain alive in the server.

2. **No liveness check**: `ensureBrowser()` checks only `state.context !== null`, not whether the context's underlying browser process is still alive. A dead context is silently reused.

3. **No abort signal handling**: The `execute()` function receives `context.abort: AbortSignal` from opencode's ToolContext, but never listens to it. When the LLM times out a tool call (30s default), the signal fires — but Chromium operations continue in the background, wedging the state.

4. **Persistent profile**: `chromium.launchPersistentContext()` with `~/.opencode/browser-profile/` accumulates stale databases (LevelDB LOCK files, Singleton* files) across interrupted sessions.

## Fix Applied
Created `browser-safety.ts` plugin (loaded after opencode-browser-plugin):
- `tool.execute.before`: Kills zombie Chromium processes and removes stale lock files before browser operations
- `tool.execute.after`: Cleans up zombie processes after failed browser operations
- `tool.browser_clean`: Diagnostic tool to explicitly clean browser state
- `tool.browser_health`: Diagnostic tool to check Playwright/Chromium installation and profile state
- `event` handler: Cleans up zombie processes when sessions end

## AGENTS.md Fix
Updated the Browser Tool section with:
- Pre-launch checklist (profile cleanup, health check)
- Safety tools documentation (browser_clean, browser_health)
- Hang recovery procedure with bash-based fallback

## Files Changed
- `.opencode/plugins/browser-safety.ts` (new)
- `.opencode/plugins/browser-safety.test.ts` (new)
- `.opencode/opencode.jsonc` (registered safety plugin)
- `opencode/AGENTS.md` (updated browser section)
- `basculer/AGENTS.md` (mentioned browser-safety plugin)
