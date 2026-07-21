#!/bin/bash
# validate-opencode-config.sh — Quick sanity checks for opencode configuration.
# Run this after editing opencode.jsonc or plugins/*.ts in opencode-config/
# to catch errors before they manifest as runtime failures.
#
# Usage: ./validate-opencode-config.sh
#   --fix     auto-fix bash script permissions
#   --quiet   only output on failure

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"       # opencode-config/tests/
OPENCODE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"       # opencode-config/
REPO_ROOT="$(cd "$OPENCODE_DIR/.." && pwd)"        # repo root (basculer/)
CONFIG_DIR="$OPENCODE_DIR/opencode"                # opencode-config/opencode/

BOLD=""; RED=""; GREEN=""; RESET=""
if [ -t 1 ]; then
	BOLD="\033[1m"; RED="\033[31m"; GREEN="\033[32m"; RESET="\033[0m"
fi

quiet=false; fix=false
for arg in "$@"; do
	case "$arg" in --quiet) quiet=true ;; --fix) fix=true ;; esac
done

pass=0; fail=0
done_msg() {
	local name="$1" status="$2"
	[ "$quiet" = true ] && return
	if [ "$status" = "pass" ]; then echo -e "  ${GREEN}✓${RESET} $name"
	else echo -e "  ${RED}✗${RESET} $name"; fi
}

echo -e "\n${BOLD}Validating opencode-config${RESET}\n"

# ── 1. Bash syntax ──────────────────────────────────────────────────
if bash -n "$CONFIG_DIR/cleanup-mcp.sh" 2>/dev/null; then
	pass=$((pass+1)); done_msg "cleanup-mcp.sh syntax" pass
else
	fail=$((fail+1)); done_msg "cleanup-mcp.sh syntax" fail
fi

# ── 2. Executable bit ───────────────────────────────────────────────
if [ -x "$CONFIG_DIR/cleanup-mcp.sh" ]; then
	pass=$((pass+1)); done_msg "cleanup-mcp.sh +x" pass
elif [ "$fix" = true ]; then
	chmod +x "$CONFIG_DIR/cleanup-mcp.sh"
	pass=$((pass+1)); done_msg "cleanup-mcp.sh +x (fixed)" pass
else
	fail=$((fail+1)); done_msg "cleanup-mcp.sh +x" fail
fi

# ── 3. Opencode config loading ──────────────────────────────────────
if [ "$quiet" = false ]; then
	echo -e "\n  Loading opencode config (opencode debug config)..."
fi

# Must run from repo root so opencode discovers .opencode/ and opencode.jsonc
cd "$REPO_ROOT"
if timeout 15 opencode debug config > /tmp/opencode-validate.log 2>&1; then
	pass=$((pass+1)); done_msg "opencode config loads" pass
else
	msg=$(head -3 /tmp/opencode-validate.log)
	fail=$((fail+1)); done_msg "opencode config loads — $msg" fail
fi

# ── 4. Summary ──────────────────────────────────────────────────────
total=$((pass + fail))
echo -e "\n${BOLD}Results:${RESET} $pass/$total passed"
if [ "$fail" -gt 0 ]; then
	echo -e "${RED}${fail} check(s) failed. Fix before restarting opencode.${RESET}"
	exit 1
fi
echo -e "${GREEN}All good.${RESET}"
