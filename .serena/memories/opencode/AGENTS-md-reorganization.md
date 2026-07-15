# `opencode-config/AGENTS.md` Reorganization (Jul 2026)

## What changed
Reorganized `opencode-config/AGENTS.md` for clarity while preserving ALL content.

## Key constraint
`opencode-config/AGENTS.md` is the only AGENTS.md auto-loaded when running opencode from `opencode-config/`. Content cannot be moved to `basculer/AGENTS.md` or `opencode/AGENTS.md`.

## Structural changes

| Before | After |
|--------|-------|
| Overview | Overview (expanded with auto-load note) |
| Architecture (with formatting bug) | Architecture (fixed blank line, audited entries) |
| Subcomponents table | — merged into → |
| Configuration list | — merged into → |
| *(new)* | **Integration & Usage** (combined Usage + Integration Points) |
| *(combined above)* | **Configuration Files** (unified table) |
| Dependencies | Dependencies |
| Subagent Addressing | → **Conventions → Subagent Addressing** (reparented) |
| Usage | → elevated into **Integration & Usage** |

## Architecture tree fixes
- Removed blank line after opening ```
- Removed `context-mode/` (doesn't exist as directory; preserved as optional dependency)
- Added `patches/`, `plugins/`, `.github/`, `model-matters.md`, `model-comparison.md`

## File
`opencode-config/AGENTS.md` — 68 lines (was 60). The slight increase is from expanded Overview and more complete tree.
