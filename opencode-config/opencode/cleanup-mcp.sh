#!/bin/bash
# cleanup-mcp.sh — Kill orphaned serena processes older than 1 hour.
# Serena is per-session (one per opencode attach) and accumulates when
# sessions disconnect without cleanup. Brave-search and context7 are
# shared HTTP daemons — not cleaned here.
#
# Safe: only kills processes >1h old. Active sessions with younger
# serenas are unaffected. The server respawns killed instances.
#
# Install: */30 * * * * /home/rongzhou/.config/opencode/cleanup-mcp.sh

ps -eo pid,etimes,args --no-headers 2>/dev/null \
  | grep "serena start-mcp-server" \
  | awk '$2 > 3600 { print $1 }' \
  | xargs -r kill 2>/dev/null
