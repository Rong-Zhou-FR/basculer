## OpenCode Directory Structure Rules

**IMPORTANT**: OpenCode interprets .md files in specific directories as special entities:
- `opencode/agents/*.md` → treated as agent configs
- `opencode/commands/*.md` → treated as custom commands

### Rule
All agents should push back against adding:
1. Non-agent .md files to `opencode/agents/` (e.g., model-matters.md, notes.md)
2. Non-command .md files to `opencode/commands/`

**Reason**: OpenCode will misinterpret these as agents/commands, causing issues.

### Correct Locations
- Agent documentation → `opencode/` (root) or `opencode/docs/`
- Command documentation → `opencode/` (root) or `opencode/docs/`
- Model recommendations → `opencode/model-matters.md` (root, not agents/)

### Example
- ❌ Wrong: `opencode/agents/model-matters.md` (treated as agent!)
- ✅ Correct: `opencode/model-matters.md` (documentation)