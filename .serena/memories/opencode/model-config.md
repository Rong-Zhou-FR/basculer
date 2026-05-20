# OpenCode Model Configuration Rule

## Rule
All agent model configs must be in `opencode.json` only. Never in YAML frontmatter of agent .md files.

## Rationale
- Consistency - single source of truth
- JSON is the canonical config format
- YAML frontmatter models can override JSON causing confusion

## How to Configure
Edit `opencode.json` -> `agent` section:
```json
"agent": {
  "expert": { "model": "minimax-m2.5-free" }
}
```

## History
- 2025-04-30: Removed model from expert.md YAML frontmatter