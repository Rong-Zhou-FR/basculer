# MCP Lifecycle Strategy — Orphaned Process Management

## Problem

`opencode serve --port 4096` launches MCP server subprocesses per-attach-session
(serena) but never kills them when the attach session ends.
Over time, instances accumulate with redundant LSP servers, consuming resources
and causing tool calls to timeout.

Observed: 6 serena MCP server instances accumulated over
~3.5 hours of server uptime.

## Current Architecture

Three-tier mitigation implemented via commit `f412531`:

| Tier | MCP Server | Strategy | Rationale |
|------|-----------|----------|-----------|
| 1. Shared HTTP daemon | brave-search | `mcp-daemon.ts` plugin starts one shared instance on port 8124. All sessions connect via `type: remote`. | Stateless — no per-session state needed. |
| 2. Local proxy | context7 | `context7-mcp-proxy.mjs` reads key from file, connects via Streamable HTTP. Config uses `type: "local"`. | Stateful (MCP session ID per connection), but one proxy per session is lightweight (~20 MB). |
| 3. Per-session + cron | serena | `serena start-mcp-server` spawned per-session. `cleanup-mcp.sh` cron kills serenas with etime >3600s every 30min. | Stateful (LSP, memories per project) — must be per-session. Cron bounds accumulation (~230 MB each). |

## Process Model

```
opencode serve --port 4096  (PID 24119, parent of all MCP servers)
├── serena start-mcp-server  (per-attach-session instance, cleaned by cron)
├── node context7-mcp-proxy  (per-attach-session instance, lightweight)
├── brave-search-mcp-server  (SINGLE shared instance via mcp-daemon plugin)
└── opencode attach ...      (clients, NOT children of server)
```

- MCP server processes are direct children of the server process (PPID = server PID)
- `opencode attach` sessions are clients connecting via HTTP, NOT parent processes
- Each attach session triggers the server to spawn a fresh serena/context7 subprocess
- When attach session ends, the server does NOT reap the MCP subprocess
- No PID-to-session mapping is available externally

## Design Decisions

### Why not wrap MCP commands with "kill old before start new"?

**Rejected** because serena/context7 are per-session, not shared.
Killing the "old" instance would kill an active session's MCP connection.

### Why not a shared serena daemon?

Per-project sharing doesn't save memory in worktree-isolated workflows where
every session targets a different directory. Each session needs its own serena
with the correct project's LSP and memories.

## Limitations

- `opencode serve` still doesn't reap subprocesses ([upstream issue #12913](https://github.com/anomalyco/opencode/issues/12913))
- Cron-based cleanup is best-effort: a serena that's 59 minutes old won't be killed
- No per-agent tools (no `mcp_health`/`mcp_clean`) — rely on cron only
