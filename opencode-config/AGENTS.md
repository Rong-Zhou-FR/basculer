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
├── scripts/             # Utility scripts
│   └── migrate-serena-memories.sh   # Copy serena memories → Gortex
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

## Config Loading Semantics (restart the server, not the client)

**In a detached client-server model (`opencode serve` + `opencode attach`, as used by
lighter-dev.bash), config is loaded ONCE at SERVER start time — not per-client, not
per-session, not on attach.** The server caches the merged config (opencode.jsonc +
agents/*.md + plugins) in memory for its entire lifetime. Attaching a client does NOT
re-read the config files; it receives the server's already-loaded copy.

Consequences:

- **Editing `opencode.jsonc` or `agents/*.md` has ZERO effect on a running server.**
  The change only takes effect after the server process restarts and re-loads config.
- **Do not tell users to "restart opencode" or "restart the client/TUI"** — that
  re-attaches to the same stale server. The correct fix is restarting the **server**
  (e.g. `opencode serve --port <port>`), not the client.
- **No-restart workaround (verified on opencode 1.18.18): `POST /global/dispose`**
  tells the running server to tear down all project instances; the next request
  touching a project recreates its instance by re-reading `opencode.jsonc`,
  `agents/*.md`, `commands/*.md`, `skills/*.md` and plugins from disk. Commands
  added/edited on disk appear immediately. The server process and attached clients
  stay up; in-flight LLM responses are interrupted. What it does NOT reload:
  server-level flags (`--port`, `--pure`), the binary, env captured at boot, and
  state cached at boot in the global config cache (use a full restart for those).
  lighter-dev.bash exposes this as `./lighter-dev.bash reload` (y/N prompt).
- **Symptom → fix**:
  - User reports "I changed the model/provider/permissions/MCP config but it's not working"
  - → First suspect a stale server. Invite the user to restart the server before
    debugging further.
  - `opencode debug config` prints the config as a FRESH process sees it. If it differs
    from what sessions are actually using, the running server is stale — restart it.
  - **Verify mechanically, don't assume:** compare the server's start time
    (`ps -o lstart -p <pid>`) with the config file's mtime (`stat -c %y opencode.jsonc`).
    If the server started before the config was edited, it is stale by definition —
    no source-level debugging needed to explain the symptom.
- **Also check `~/.local/state/opencode/model.json`** — the `recent` list there feeds
  `defaultModel()` (when no global `model` is set) and the client's "recent" fallback.
  A stale top entry (e.g. pointing at an old provider) can override expected defaults
  even after a server restart. This state can silently override a config that is
  itself correct. Fix: clean the entry, or set a global `model` in `opencode.jsonc` —
  `defaultModel()` checks it FIRST, short-circuiting the `recent` list entirely.

## Provider Model Pinning (keyed by exact ID)

OpenRouter provider options are keyed by the **exact model ID** — a pin on
`deepseek/deepseek-v4-flash` does NOT apply to `deepseek/deepseek-v4-flash-0731`
or the `~deepseek/deepseek-v4-flash-latest` auto alias. Hand-selecting one of
those IDs silently falls back to OpenRouter's default auto-provider routing.

When pinning a model family to a specific endpoint, pin **every selectable ID**:
the base ID, dated checkpoints, and `~` aliases. Keep them in sync when the
endpoint changes.

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
- [Gortex](https://github.com/zzet/gortex) — Code intelligence daemon (single Go binary, tree-sitter based)
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

### Code Intelligence: Gortex (primary) + Serena (fallback)

Serena has been **replaced by Gortex** as the primary code intelligence engine (see [issue #37](https://github.com/Rong-Zhou-FR/basculer/issues/37)):

| Aspect | Serena (disabled) | Gortex (active) |
|--------|-------------------|-----------------|
| Architecture | Per-session Python + LSP | Single Go daemon, tree-sitter |
| Memory (7 repos) | ~4.2 GB (600 MB × 7) | ~64 MiB (single daemon) |
| MCP tools | 27 tools | 100+ tools |
| Startup | 7 concurrent processes, LSP races | Daemon pre-indexed, instant attach |
| Session isolation | Per-session process | Built into daemon |
| Memory system | Flat markdown files | Structured graph entries |
| Install | `serena start-mcp-server` | `gortex daemon start --detach` |

Gortex daemon runs as a systemd --user service (`com.zzet.gortex.service`), auto-starting on login. It tracks all repos in the lighter-dev workspace. `gortex mcp` proxies MCP requests from opencode to the daemon.

**Serena is disabled** (`"enabled": false` in `opencode.jsonc`) but kept in config for easy one-field re-enable. Serena memories were copied (not moved) to Gortex via `migrate-serena-memories.sh`.

See [issue #37](https://github.com/Rong-Zhou-FR/basculer/issues/37) for the experiment rationale and [issue #34](https://github.com/Rong-Zhou-FR/basculer/issues/34) for the original MCP lifecycle discussion.

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
