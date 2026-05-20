# Opencode AGENTS.md

## Overview
opencode configuration for AI-assisted coding

## Architecture
```
opencode/
├── agents/           # Agent configs (architect, reviewer, etc.)
├── context-mode/    # Context-mode sessions and content
├── opencode.json    # Main config
└── package.json     # Dependencies
```

## Subcomponents
| Component | Purpose |
|-----------|---------|
| agents/ | Individual agent configs (architect.md, reviewer.md, etc.) |
| context-mode/ | Indexed sessions and content for context-mode |
| opencode.json | Model selection, tool configuration |

## Configuration
- `opencode.json` - Primary config (model, tools, context settings)
- `agents/*.md` - Agent-specific instructions

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
