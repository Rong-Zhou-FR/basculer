# Opencode config AGENTS.md

## Overview
opencode configuration for AI-assisted coding. This is the system-prompt for opencode agents — when running opencode from this directory, this file is loaded automatically and applies to all agents specified in `agents/`.

## Architecture
```
opencode/
├── AGENTS.md           # System prompt — applied to all agent sessions
├── agents/             # Individual agent configs (architect, reviewer, etc.)
├── commands/           # Custom slash-command definitions (review, test, etc.)
├── opencode.jsonc      # Main config (model, tools, context settings)
├── patches/            # Model-config patches
├── plugins/            # Plugin configurations
├── .github/            # GitHub CI/CD workflows
├── .secrets/           # Local secrets (gitignored via `*.secrets*` at repo root)
├── package.json        # Dependencies and scripts
├── model-matters.md    # Model recommendation notes
├── model-comparison.md # Model comparison notes
└── ...                 # Additional config and documentation files
```

Project-local plugins and state live alongside the project's `.opencode/` directory (not symlinked):
```
.basculer/opencode-config/.opencode/
├── opencode.jsonc       # Plugin registration (browser-safety, worktree-enhanced, etc.)
├── plugins/
│   ├── browser-safety.ts  → (symlink to ~/kodo/opencode-tweaks/opencode-safe-playwright/src/index.ts)
│   ├── worktree.ts        → (symlink to ~/kodo/opencode-tweaks/opencode-worktree-enhanced/src/index.ts)
│   └── kdco-primitives/   # Shared utility modules (local files, no symlink)
├── tests/               # Plugin test files (worktree.test.ts, browser-safety.test.ts)
├── package.json         # Plugin npm dependencies (@opencode-ai/plugin, zod, etc.)
├── worktree.jsonc       # Worktree plugin config (sync, hooks, terminal mode)
└── worktree-state.sqlite # Worktree session state database
```

## Integration & Usage
- Uses `opencode/` as config directory. Symlink it to `~/.config/opencode/`:
  ```
  ln -sf ~/.basculer/opencode-config/opencode ~/.config/opencode
  ```
  Or symlink only the agents directory:
  ```
  ln -sf ~/.basculer/opencode-config/opencode/agents ~/.config/opencode/agents
  ```
- Project-local `.opencode/` is auto-loaded by opencode from the project root — no symlink needed.
- Install the CLI: `npm install -g opencode`
- Run: `opencode` from a project root to activate local plugins.

## Configuration Files

| File / Directory | Purpose |
|-----------------|---------|
| `AGENTS.md` | System prompt — instructions applied to every agent session |
| `agents/*.md` | Individual agent definitions (architect, refactorer, tester, etc.) |
| `commands/*.md` | Custom slash-command definitions (`/review`, `/test`, etc.) |
| `opencode.jsonc` | Primary configuration: model selection, tool flags, context settings |
| `.secrets/` | Local secrets (gitignored) — API keys, tokens |
| `patches/` | Model-config patches |
| `plugins/` | Plugin configurations |
| `package.json` | Dependencies and scripts |

## Plugins

Custom plugins live in `.opencode/plugins/` and are registered in `.opencode/opencode.jsonc`.
Source repos are symlinked from `~/kodo/opencode-tweaks/`.

### Plugin table

| Plugin | Tools | Source repo | Symlink path | Registered? |
|--------|-------|------------|-------------|-------------|
| **browser-safety** | `browser_health`, `browser_clean` | [opencode-safe-playwright](https://github.com/Ron-RONZZ-org/opencode-safe-playwright) → `~/kodo/opencode-tweaks/opencode-safe-playwright/src/index.ts` | `.opencode/plugins/browser-safety.ts` | Yes, in `opencode.jsonc` |
| **worktree-enhanced** | `worktreeCreate`, `worktreeDelete`, `worktreeList` | [opencode-worktree-enhanced](https://github.com/Ron-RONZZ-org/opencode-worktree-enhanced) → `~/kodo/opencode-tweaks/opencode-worktree-enhanced/src/index.ts` | `.opencode/plugins/worktree.ts` | No — add to `opencode.jsonc` to activate |
| **kdco-primitives** | Shared utilities (shell, mutex, terminal-detect, cmux, etc.) | Inline in `.opencode/plugins/kdco-primitives/` | Local files, no symlink | N/A (internal) |

### How to edit a plugin

1. **Edit the source** in `~/kodo/opencode-tweaks/<repo>/` (e.g. `~/kodo/opencode-tweaks/opencode-worktree-enhanced/src/git.ts`)
2. **Run tests** — each repo has its own test suite:
   ```bash
   cd ~/kodo/opencode-tweaks/opencode-worktree-enhanced && bun test tests/
   cd ~/kodo/opencode-tweaks/opencode-safe-playwright && bun test tests/
   ```
3. **Changes take effect immediately** — the opencode server hot-reloads plugin source on restart. No rebuild step needed.

### How to add a new plugin

```bash
# 1. Symlink the source
ln -sf ~/kodo/opencode-tweaks/<new-plugin>/src/index.ts <project>/.opencode/plugins/<name>.ts

# 2. Register in opencode.jsonc
# Add to the "plugin" array:
"plugin": [
  "./plugins/browser-safety.ts",
  "./plugins/<name>.ts"
]
```

## Dependencies
- [opencode](https://www.npmjs.com/package/opencode) — AI coding assistant (npm package)
- [@opencode-ai/plugin](https://www.npmjs.com/package/@opencode-ai/plugin) — Plugin SDK (installed in `.opencode/package.json`)
- context-mode (optional) — for session indexing and persistent context

## Conventions

### Subagent Addressing
When referring to subagents in natural language commands, use the `@` notation:
- `@architect` — system design, tech stack decisions
- `@refactorer` — code improvements, restructuring
- `@reviewer` — code quality, security reviews
- `@tester` — test creation, coverage analysis
- `@debugger` — bug diagnosis, error analysis
- `@explore` — codebase navigation, file finding
- `@planner` — task breakdown, orchestration
- `@expert` — after trying 3+ approaches, searched docs, still stuck
- `@githubber` — GitHub operations
- `@huggingfacer` — Hugging Face operations

**Note**: When delegating via `task` tool, use plain name (no `@`): `subagent_type: "debugger"`
