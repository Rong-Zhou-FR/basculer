# API Key Management Patterns

## Negative Pattern (what broke)
Raw API keys hardcoded in `opencode.jsonc`:

```json
// ❌ BAD — key lives in tracked config, exposed in git history
"headers": { "CONTEXT7_API_KEY": "ctx7sk-..." }
```

Also: `{file:...}` syntax in headers doesn't work:

```json
// ❌ BAD — opencode doesn't support {file:...} in headers
"headers": { "Authorization": "Bearer {file:~/.config/opencode/.secrets/github-pat}" }
```

## Positive Patterns (file-based)

### Pattern 1: Local MCP with wrapper script (brave-search)
For local MCP servers that expect the key as a CLI arg or env var:

1. Store key in `opencode/.secrets/<name>-api-key` (gitignored via `*.secrets*`)
2. Create a shell wrapper that reads the file and passes the key to the MCP server
3. Config references the wrapper + file path via `environment`

`opencode/brave-search-wrapper.sh`:
```bash
BRAVE_API_KEY=$(cat "$BRAVE_API_KEY_FILE")
exec brave-search-mcp-server --brave-api-key "$BRAVE_API_KEY"
```

`opencode.jsonc`:
```json
"brave-search": {
  "type": "local",
  "command": ["~/.config/opencode/brave-search-wrapper.sh"],
  "environment": {
    "BRAVE_API_KEY_FILE": "~/.config/opencode/.secrets/brave-api-key"
  }
}
```

### Pattern 2: Remote MCP with proxy script (context7)
For remote MCP servers that authenticate via headers:

1. Store key in `opencode/.secrets/<name>-api-key`
2. Write a Node.js proxy that reads the key from file, connects to the remote
   MCP (Streamable HTTP), and bridges stdio ↔ remote
3. Config uses `type: "local"` pointing to the proxy script

`opencode/context7-mcp-proxy.mjs`:
- Reads `CONTEXT7_API_KEY_FILE` env var
- POSTs to remote with key in header
- Manages MCP session ID automatically
- Parses SSE responses and writes JSON-RPC to stdout

`opencode.jsonc`:
```json
"context7": {
  "type": "local",
  "command": ["node", "~/.config/opencode/context7-mcp-proxy.mjs"],
  "environment": {
    "CONTEXT7_API_KEY_FILE": "~/.config/opencode/.secrets/context7-api-key"
  }
}
```

### Pattern 3: Server reads file directly (ideal but server-dependent)
If the MCP server supports `*_KEY_FILE` env vars natively
(e.g., reads the key from a file path), just pass the file path.
This is the cleanest pattern but requires server support.

## Gitignore
Repo root `.gitignore` has `*.secrets*` which covers all `opencode/.secrets/*` files.

## Key files & wrappers
| File | Purpose |
|------|---------|
| `opencode/.secrets/brave-api-key` | Brave Search API key |
| `opencode/.secrets/context7-api-key` | Context7 API key |
| `opencode/.secrets/github-pat` | GitHub personal access token (unused) |
| `opencode/brave-search-wrapper.sh` | Shell wrapper for brave-search MCP |
| `opencode/context7-mcp-proxy.mjs` | Node.js proxy for context7 remote MCP |
