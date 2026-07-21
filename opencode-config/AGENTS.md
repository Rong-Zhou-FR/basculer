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
.basculer/opencode-config/
├── AGENTS.md            # This file — system prompt for agent sessions
├── opencode/            # Config files — symlinked to ~/.config/opencode
│   ├── opencode.jsonc   # Main config (MCP servers, permissions, providers, agents)
│   ├── plugins/         # Global plugin sources (worktree, metasearch, mcp-daemon)
│   ├── cleanup-mcp.sh   # Cron script to kill orphaned serena instances (>1h)
│   └── .secrets/        # Local API keys (gitignored via *.secrets*)
├── .opencode/           # Project-local plugins — auto-loaded by opencode
│   ├── opencode.jsonc   # Plugin registration (browser-safety, etc.)
│   ├── plugins/
│   │   ├── browser-safety.ts  → (symlink)
│   │   ├── worktree.ts        → (symlink)
│   │   └── kdco-primitives/
│   ├── tests/           # Plugin test files
│   └── package.json
└── tests/               # Config validation scripts
    └── validate-opencode-config.sh
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
| **worktree-enhanced** | `worktreeCreate`, `worktreeDelete`, `worktreeList` | [opencode-worktree-enhanced](https://github.com/Ron-RONZZ-org/opencode-worktree-enhanced) → `~/kodo/opencode-tweaks/opencode-worktree-enhanced/src/index.ts` | Global: `~/.config/opencode/plugins/opencode-worktree-enhanced/` → `src/` | Yes, globally in `~/.config/opencode/opencode.jsonc` |
| **kdco-primitives** | Shared utilities (shell, mutex, terminal-detect, cmux, etc.) | Inline in `.opencode/plugins/kdco-primitives/` | Local files, no symlink | N/A (internal) |

### How to edit a plugin

1. **Edit the source** in `~/kodo/opencode-tweaks/<repo>/` (e.g. `~/kodo/opencode-tweaks/opencode-worktree-enhanced/src/git.ts`)
2. **Run tests** — each repo has its own test suite:
   ```bash
   cd ~/kodo/opencode-tweaks/opencode-worktree-enhanced && bun test tests/
   cd ~/kodo/opencode-tweaks/opencode-safe-playwright && bun test tests/
   ```
3. **Changes take effect immediately** on opencode client restart — no rebuild step needed.

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

## API Key Management

### Rule
**Never put raw API keys, tokens, or secrets in `opencode.jsonc`.** They are exposed in git history and visible to anyone with repo access.

### Mechanism
All secrets live in `opencode/.secrets/` — files are gitignored by the `*.secrets*` pattern in the repo root `.gitignore`.

### Two approaches (pick by MCP server type)

| Approach | When | Example |
|----------|------|---------|
| **Shared HTTP daemon** | Stateless MCP server with native HTTP transport | `mcp-daemon.ts` starts brave-search on port 8124. All sessions connect via `type: remote`. |
| **Local proxy script** | Remote MCP server that needs a file-based auth key | `context7-mcp-proxy.mjs` reads key from file, connects to remote MCP via Streamable HTTP, bridges stdio↔remote. Config uses `type: "local"` pointing to the proxy. |

**Important**: OpenCode does NOT support `{file:path}` interpolation in config values. It supports `{env:VAR_NAME}` for environment variables. For file-based secrets, use a local wrapper/proxy script that reads the key from file at startup.

### Examples
```jsonc
// ✅ Shared HTTP daemon (brave-search)
"brave-search": {
  "type": "remote",
  "url": "http://127.0.0.1:8124/mcp",
  "enabled": true
}

// ✅ Local proxy with file-based key (context7)
// The proxy reads CONTEXT7_API_KEY_FILE env var — never in tracked config.
"context7": {
  "type": "local",
  "command": ["node", "/home/rongzhou/.config/opencode/context7-mcp-proxy.mjs"],
  "environment": {
    "CONTEXT7_API_KEY_FILE": "/home/rongzhou/.config/opencode/.secrets/context7-api-key"
  },
  "enabled": true,
  "timeout": 30000
}

// ❌ NEVER — key in plaintext in tracked config:
// "headers": { "CONTEXT7_API_KEY": "ctx7sk-..." }
```

## Validation

After editing `opencode.jsonc` or any plugin, run the validation script to catch errors early:

```bash
./tests/validate-opencode-config.sh
```

This checks:
- Bash syntax of shell scripts
- Opencode config loads successfully (schema validation + plugin compilation)

## MCP Lifecycle Strategy

Orphaned MCP server processes accumulate because `opencode serve` doesn't clean up subprocesses when attach sessions disconnect ([upstream issue #12913](https://github.com/anomalyco/opencode/issues/12913)).

Three-tier mitigation:

1. **Shared HTTP daemons** (brave-search) — Stateless servers run as a single HTTP instance via `mcp-daemon.ts` plugin. All sessions share one connection.
2. **Local proxy** (context7) — Local proxy script reads key from file, connects via Streamable HTTP. No per-session overhead.
3. **Per-session + cron cleanup** (serena) — Serena is stateful (LSP, memories per project). Stays per-session. Cron kills orphans >1h every 30min (`cleanup-mcp.sh`).

Serena proxy rejected: per-project sharing doesn't save memory in worktree-isolated workflows where every session targets a different directory.

See [issue #34](https://github.com/Rong-Zhou-FR/basculer/issues/34) for full discussion.

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
