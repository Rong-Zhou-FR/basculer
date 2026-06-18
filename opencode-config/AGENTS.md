# Opencode config AGENTS.md

## Overview
opencode configuration for AI-assisted coding

## Architecture
```

./opencode/
├── agents/           # Agent configs (architect, reviewer, etc.)
├── commands/         # Custom slash-commands (review, test, etc.)
├── context-mode/    # Context-mode sessions and content
├── opencode.jsonc   # Main config
├── .secrets/        # Local secrets (gitignored)
└── package.json     # Dependencies
└── AGENTS.md       # system-prompt for opencode agents, apply to all agents specified in agents/
```

## Subcomponents
| Component | Purpose |
|-----------|---------|
| agents/ | Individual agent configs (architect.md, reviewer.md, etc.) |
| commands/ | Custom slash-command definitions |
| context-mode/ | Indexed sessions and content for context-mode |
| opencode.jsonc | Model selection, tool configuration |
| .secrets/ | Local secrets (git-ignored via `*.secrets*` at repo root) |

## Configuration
- `opencode/AGENTS.md`
- `opencode/opencode.jsonc` - Primary config (model, tools, context settings)
- `opencode/agents/*.md` - Agent-specific instructions
- `opencode/commands/*.md` - Custom slash-command definitions

## Dependencies
- opencode (npm package)
- context-mode (optional, for session indexing)

## Integration Points
- Uses `opencode/` as config directory
- Agents read from project local config

## Subagent Addressing
When referring to subagents in natural language commands, use the `@` notation:
- `@architect` - system design, tech stack decisions
- `@refactorer` - code improvements, restructuring  
- `@reviewer` - code quality, security reviews
- `@tester` - test creation, coverage analysis
- `@debugger` - bug diagnosis, error analysis
- `@explore` - codebase navigation, file finding
- `@planner` - task breakdown, orchestration
- `@expert` - after trying 3+ approaches, searched docs, still stuck
- `@githubber` - GitHub operations
- `@huggingfacer` - Hugging Face operations

**Note**: When delegating via `task` tool, use plain name (no `@`): `subagent_type: "debugger"`

## Usage
- Symlink to: `~/.config/opencode` or `~/.config/opencode/agents`
- Install: `npm install -g opencode`
- Run: `opencode`
