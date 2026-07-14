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

## Integration & Usage
- Uses `opencode/` as config directory. Symlink it to `~/.config/opencode/`:
  ```
  ln -sf ~/.basculer/opencode-config/opencode ~/.config/opencode
  ```
  Or symlink only the agents directory:
  ```
  ln -sf ~/.basculer/opencode-config/opencode/agents ~/.config/opencode/agents
  ```
- Agents read from project local config at runtime.
- Install the CLI: `npm install -g opencode`
- Run: `opencode`

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

## Dependencies
- [opencode](https://www.npmjs.com/package/opencode) — AI coding assistant (npm package)
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
