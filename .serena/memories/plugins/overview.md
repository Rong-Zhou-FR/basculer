# opencode Plugin Organization

## Overview

Custom plugins extend opencode's toolset. Each plugin is developed in its own
repo under `~/kodo/opencode-tweaks/`, symlinked into `.opencode/plugins/`, and
registered in `.opencode/opencode.jsonc`.

## Plugin table

| Plugin | Tools | Source repo | Symlink | Registered? |
|--------|-------|------------|---------|-------------|
| **browser-safety** | `browser_health`, `browser_clean` | [opencode-safe-playwright](https://github.com/Ron-RONZZ-org/opencode-safe-playwright) → `~/kodo/opencode-tweaks/opencode-safe-playwright/src/index.ts` | `.opencode/plugins/browser-safety.ts` | Yes, in `opencode.jsonc` |
| **worktree-enhanced** | `worktreeCreate`, `worktreeDelete`, `worktreeList` | [opencode-worktree-enhanced](https://github.com/Ron-RONZZ-org/opencode-worktree-enhanced) → `~/kodo/opencode-tweaks/opencode-worktree-enhanced/src/index.ts` | Global: `~/.config/opencode/plugins/opencode-worktree-enhanced/` → `src/` | Yes, globally in `~/.config/opencode/opencode.jsonc` |
| **kdco-primitives** | Shared utilities (shell, mutex, etc.) | Inline in `.opencode/plugins/kdco-primitives/` | Local files, no symlink | N/A (internal) |

## worktree-enhanced Squash Merge Fix

### Problem
`worktreeDelete` uses `git merge-base --is-ancestor` to check if a branch is merged into main. This fails for squash/rebase merges because original branch commits are never ancestors of main (different hash after squash).

### Fix
- **`validateBranchMerged()` in `src/git.ts`**: Two-tier detection:
  1. `git merge-base --is-ancestor` (fast path — regular merges)
  2. `git diff --quiet main..<branch>` (fallback — catches squash where trees match)
- **`worktreeDelete` tool in `src/index.ts`**: Added `--force` parameter:
  - Without `--force`: runs both checks. If both fail, hard-refuses with message suggesting `--force`.
  - With `--force`: skips merge validation entirely.
- Neither method is 100% reliable for squash merges (conflict resolution during squash produces different trees). The `--force` escape hatch is the ultimate fallback.

### Documentation
- `AGENTS.md` plugin table and worktree cleanup guidance
- `commands/cleanup.md` merge-check table row updated
- `commands/worktree-delete.md` `--force` workflow

## Editing workflow

1. **Edit** the source in `~/kodo/opencode-tweaks/<repo>/` (e.g., `src/git.ts` for worktree-enhanced)
2. **Run tests**: `cd ~/kodo/opencode-tweaks/<repo>/ && bun test tests/`
3. **Restart opencode** — plugins are hot-reloaded on server restart, no build step

## Architecture

Project-local plugins live in `opencode-config/.opencode/plugins/` and are registered in `opencode-config/.opencode/opencode.jsonc`. Global plugins are symlinked under `~/.config/opencode/plugins/` and registered in `~/.config/opencode/opencode.jsonc`.

Source repos are symlinked from `~/kodo/opencode-tweaks/`:

| Plugin | Tools | Symlink | Registered? |
|--------|-------|---------|-------------|
| **browser-safety** | `browser_health`, `browser_clean` | `plugins/browser-safety.ts` → `~/kodo/opencode-tweaks/opencode-safe-playwright/src/index.ts` | Yes, in `opencode.jsonc` |
| **worktree-enhanced** | `worktreeCreate`, `worktreeDelete`, `worktreeList` | Global: `~/.config/opencode/plugins/opencode-worktree-enhanced/` → `src/` | Yes, globally |
| **kdco-primitives** | Shared utilities (shell, mutex, etc.) | Local files in `plugins/kdco-primitives/` | N/A (internal) |

## worktree-enhanced Squash Merge Fix

### Problem
`worktreeDelete` uses `git merge-base --is-ancestor` to check if a branch is merged into main. This fails for squash/rebase merges because the original branch commits are never ancestors of main (they get a different hash after squash).

### Fix (opencode-worktree-enhanced)
- **`validateBranchMerged()` in `src/git.ts`**: Two-tier detection:
  1. `git merge-base --is-ancestor` (fast path — regular merges)
  2. `git diff --quiet main..<branch>` (fallback — catches squash where trees match)
- **`worktreeDelete` tool in `src/index.ts`**: Added `--force` parameter:
  - Without `--force`: runs both checks. If both fail, hard-refuses with message suggesting `--force`.
  - With `--force`: skips merge validation entirely. Use when user confirms it's safe.
- Neither method is 100% reliable for squash merges (conflict resolution during squash produces different trees). The `--force` escape hatch is the ultimate fallback.

### Documentation
- `AGENTS.md` updated with plugin table and worktree cleanup guidance.
- `commands/cleanup.md` updated merge-check table row.
- `commands/worktree-delete.md` updated with `--force` workflow.
