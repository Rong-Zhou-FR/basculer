#!/bin/bash
# brave-search-wrapper.sh
#
# Reads BRAVE_API_KEY from a file (BRAVE_API_KEY_FILE env var),
# passes it to brave-search-mcp-server as --brave-api-key.
#
# This keeps the actual key in a gitignored file, never in the config.
#
# Usage in opencode.jsonc:
#   "command": ["/home/rongzhou/.config/opencode/brave-search-wrapper.sh"],
#   "environment": {
#     "BRAVE_API_KEY_FILE": "/home/rongzhou/.config/opencode/.secrets/brave-api-key"
#   }

set -euo pipefail

if [ -z "${BRAVE_API_KEY_FILE:-}" ]; then
  echo "FATAL: BRAVE_API_KEY_FILE not set" >&2
  exit 1
fi

BRAVE_API_KEY=$(cat "$BRAVE_API_KEY_FILE") || {
  echo "FATAL: could not read BRAVE_API_KEY_FILE: $BRAVE_API_KEY_FILE" >&2
  exit 1
}
if [[ -z "$BRAVE_API_KEY" ]]; then
  echo "FATAL: BRAVE_API_KEY_FILE is empty: $BRAVE_API_KEY_FILE" >&2
  exit 1
fi

exec brave-search-mcp-server --brave-api-key "$BRAVE_API_KEY" "$@"
