# MCP Lifecycle Plugin — Orphaned Process Analysis

## Problem

`opencode serve --port 4096` launches MCP server subprocesses per-attach-session
(serena, context7, etc.) but never kills them when the attach session ends.
Over time, instances accumulate with redundant LSP servers, consuming resources
and causing tool calls to timeout.

Observed: 6 serena MCP server instances + 10 context7 proxies accumulated over
~3.5 hours of server uptime.

## Process Model

```
opencode serve --port 4096  (PID 24119, parent of all MCP servers)
├── serena start-mcp-server  (per-attach-session instance)
├── node context7-mcp-proxy  (per-attach-session instance)
├── ...
└── opencode attach ...      (clients, NOT children of server)
```

- MCP server processes are direct children of the server process (PPID = server PID)
- `opencode attach` sessions are clients connecting via HTTP, NOT parent processes
- Each attach session triggers the server to spawn a fresh MCP server subprocess
- When attach session ends, the server does NOT reap the MCP subprocess
- No PID-to-session mapping is available externally

## Key Design Decision: No Wrapping of MCP Commands

Initial approach wrapped MCP server commands with a "kill old before start new"
bash wrapper. **Rejected** because MCP servers are per-session, not shared.
Killing the "old" instance would kill an active session's MCP connection.

## Solution — Plugin `mcp-lifecycle`

Located at `opencode/plugins/mcp-lifecycle.ts`, registered in global config.

### Layer 1: Startup cleanup
- Runs once when plugin loads at opencode server startup
- Kills ALL known MCP processes (serena, context7, etc.) using `pkill`
- Safe: no attach sessions are active during server startup

### Layer 2: On-demand cleanup tools
- `mcp_health` — lists all MCP processes with PID, age, and command
- `mcp_clean` — kills all MCP processes after confirmation
- Guidance injected into system prompt so agents know to call these tools

## Pattern for Adding New MCP Servers

Extend `KNOWN_MCP_PATTERNS` array in the plugin source.

## Process Architecture Context

`opencode serve` runs as a persistent daemon. All `opencode attach` sessions
connect to it. The server:
1. Accepts attach clients
2. Spawns MCP servers as its own children
3. Routes tool calls from client to appropriate MCP server
4. NEVER cleans up MCP servers when clients disconnect

This is a known lifecycle gap in opencode's MCP management. The plugin works
around it until opencode itself handles subprocess lifecycle.
