#!/usr/bin/env bash
#
# Tests for ronWorkspace/lighter-dev.bash
#
# These are standalone bash tests (no test framework dependency).
# Run: bash tests/test_lighter_dev.bats
#
# Covers:
#   - --help exits 0 and shows documentation
#   - --dry-run exits 0 and shows preview
#   - launch_term is defined with correct signature
#   - launch_term uses delete-wait loop (poll list-sessions after delete-session)
#   - launch_term filters EXITED sessions from readiness check
#   - launch_term probes action-readiness via query-tab-names
#   - No stale gen_layout / LAYOUT_DIR references remain
#

set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/ronWorkspace/lighter-dev.bash"
PASS=0
FAIL=0

# ── Helpers ──────────────────────────────────────────────────────────

green() { printf '\e[32m%s\e[0m\n' "$*"; }
red()   { printf '\e[31m%s\e[0m\n' "$*" >&2; }

assert_eq() {
    local expected="$1" actual="$2" msg="$3"
    if [[ "$expected" == "$actual" ]]; then
        green "  PASS  $msg"
        PASS=$((PASS + 1))
    else
        red "  FAIL  $msg"
        printf '    expected: %s\n    actual:   %s\n' "$expected" "$actual"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local haystack="$1" needle="$2" msg="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        green "  PASS  $msg"
        PASS=$((PASS + 1))
    else
        red "  FAIL  $msg"
        printf '    expected to contain: %s\n' "$needle"
        FAIL=$((FAIL + 1))
    fi
}

# ── Test: --help ─────────────────────────────────────────────────────

echo "=== --help ==="
help_out=$(bash "$SCRIPT" --help 2>&1)
assert_eq "0" "$?" "--help exit code"
assert_contains "$help_out" "lighter-dev.bash" "shows script name"
assert_contains "$help_out" "Alacritty+Zellij" "describes terminal stack"
assert_contains "$help_out" "--dry-run" "mentions --dry-run flag"

echo ""

# ── Test: --dry-run ──────────────────────────────────────────────────

echo "=== --dry-run ==="
dry_out=$(bash "$SCRIPT" --dry-run 2>&1)
assert_eq "0" "$?" "--dry-run exit code"
assert_contains "$dry_out" "Would launch" "shows preview header"
assert_contains "$dry_out" "lighter-config" "mentions workspace tabs"
assert_contains "$dry_out" "nvim README.md" "shows commands"
assert_contains "$dry_out" "opencode" "shows all workspaces"

echo ""

# ── Test: --dry-run shows opencode serve+attach mode ─────────────────

echo "=== dry-run: opencode serve+attach ==="
dry_out=$(bash "$SCRIPT" --dry-run 2>&1)
assert_contains "$dry_out" "share one server" \
    "--dry-run mentions share one server"
assert_contains "$dry_out" "opencode (attach)" \
    "--dry-run shows attach mode for regular opencode tabs"
assert_contains "$dry_out" "gitmaster (mini+attach)" \
    "--dry-run shows mini+attach for gitmaster tabs"

echo ""

# ── Test: structural checks ──────────────────────────────────────────

echo "=== structural ==="

# Source the function definitions without calling main
test_wrapper=$(mktemp)
sed '/^main "\$@"$/d' "$SCRIPT" > "$test_wrapper"
printf '\n# override — sourced for structural tests only\ntrue\n' >> "$test_wrapper"
source "$test_wrapper"

# launch_term should exist and accept tab specs
assert_contains "$(declare -f launch_term)" "action new-tab" \
    "launch_term uses action new-tab"
assert_contains "$(declare -f launch_term)" '--cwd "$workdir"' \
    "launch_term passes --cwd"
assert_contains "$(declare -f launch_term)" "delete-session --force" \
    "launch_term cleans stale sessions"
assert_contains "$(declare -f launch_term)" "go-to-tab 0" \
    "launch_term closes default tab"
assert_contains "$(declare -f launch_term)" "setsid alacritty" \
    "launch_term uses setsid for process isolation"
assert_contains "$(declare -f launch_term)" "list-sessions" \
    "launch_term polls list-sessions for session registration readiness"
assert_contains "$(declare -f launch_term)" "query-tab-names" \
    "launch_term uses query-tab-names for tab-count verification"

# launch_term should have delete-wait loop (polls after delete-session)
assert_contains "$(declare -f launch_term)" "delete_timeout" \
    "launch_term polls list-sessions after delete-session to await cleanup"
assert_contains "$(declare -f launch_term)" "Stale session" \
    "launch_term warns when stale session not removed"

# launch_term should filter EXITED sessions from readiness check
assert_contains "$(declare -f launch_term)" "grep -v '(EXITED'" \
    "launch_term filters EXITED sessions from readiness check"

# launch_term should probe action-readiness before creating tabs
assert_contains "$(declare -f launch_term)" "action_probe" \
    "launch_term probes session action-readiness before creating tabs"
assert_contains "$(declare -f launch_term)" "not responding to actions" \
    "launch_term warns when session is not action-ready"

# switch_desktop should poll until the switch takes effect
assert_contains "$(declare -f switch_desktop)" "wmctrl -d" \
    "switch_desktop polls wmctrl -d until desktop switch settles"

# No stale layout machinery
assert_eq "" "$(declare -f gen_layout 2>/dev/null || true)" \
    "gen_layout function removed"
assert_eq "" "$(echo "${LAYOUT_DIR:-}" 2>/dev/null || true)" \
    "LAYOUT_DIR constant removed"

# restore_floorp should exist and use the right internals
assert_contains "$(declare -f restore_floorp)" "pgrep -x -u" \
    "restore_floorp checks for floorp process by PID"
assert_contains "$(declare -f restore_floorp)" "session restore" \
    "restore_floorp mentions session restore"
assert_contains "$(declare -f restore_floorp)" 'grep -ic "ablaze floorp' \
    "restore_floorp counts restored windows via wmctrl"

# ── Test: opencode serve+attach constants and functions ───────────────

echo "=== opencode serve+attach ==="

# Config constants
assert_eq "4096" "$OPCODE_SERVE_PORT" "OPCODE_SERVE_PORT is 4096"
assert_eq "http://127.0.0.1:4096" "$OPCODE_SERVE_URL" "OPCODE_SERVE_URL uses 127.0.0.1"
assert_contains "${OPCODE_DAEMON_PID_FILE:-}" "/tmp/opencode-daemon.pid" \
    "OPCODE_DAEMON_PID_FILE is /tmp/opencode-daemon.pid"
assert_contains "${OPCODE_DAEMON_LOG:-}" "/tmp/opencode-daemon.log" \
    "OPCODE_DAEMON_LOG is /tmp/opencode-daemon.log"

# launch_opencode_daemon exists
assert_contains "$(declare -f launch_opencode_daemon)" "opencode serve" \
    "launch_opencode_daemon uses opencode serve"
assert_contains "$(declare -f launch_opencode_daemon)" "--port" \
    "launch_opencode_daemon passes --port"
assert_contains "$(declare -f launch_opencode_daemon)" "/global/health" \
    "launch_opencode_daemon polls /global/health"
assert_contains "$(declare -f launch_opencode_daemon)" "setsid" \
    "launch_opencode_daemon uses setsid for process isolation"
assert_contains "$(declare -f launch_opencode_daemon)" "curl -sf" \
    "launch_opencode_daemon uses curl for health check"
assert_contains "$(declare -f launch_opencode_daemon)" "PID_FILE" \
    "launch_opencode_daemon stores PID in PID_FILE"
assert_contains "$(declare -f launch_opencode_daemon)" "already running" \
    "launch_opencode_daemon checks if already running"

# CMD_OPENCODE uses attach mode
assert_contains "${CMD_OPENCODE}" "opencode attach" \
    "CMD_OPENCODE uses opencode attach"
assert_contains "${CMD_OPENCODE}" "${OPCODE_SERVE_URL}" \
    "CMD_OPENCODE references OPCODE_SERVE_URL"

# CMD_MASTER uses run --attach --mini
assert_contains "${CMD_MASTER}" "opencode run" \
    "CMD_MASTER uses opencode run"
assert_contains "${CMD_MASTER}" "--attach" \
    "CMD_MASTER uses --attach"
assert_contains "${CMD_MASTER}" "--agent gitmaster" \
    "CMD_MASTER uses --agent gitmaster"
assert_contains "${CMD_MASTER}" "--mini" \
    "CMD_MASTER uses --mini"

# Tab specs in the source contain --dir for all opencode tabs
tab_lines=$(grep -n 'opencode attach\|CMD_OPENCODE\|CMD_MASTER' "$SCRIPT" | grep -v '^\s*#' | grep -v 'CMD_OPENCODE="\|CMD_MASTER="' || true)
while IFS= read -r line; do
    # Skip lines that are comments or variable assignments
    if [[ "$line" == *"--dir"* ]] || [[ "$line" == *"--dir"* ]]; then
        continue
    fi
    # Actually let's just count that each CMD_OPENCODE/CMD_MASTER usage has --dir
done <<< "$tab_lines"

# Check tab specs for --dir usage
open_code_usage=$(grep -c '\${CMD_OPENCODE}' "$SCRIPT" 2>/dev/null || true)
open_code_with_dir=$(grep -c '\${CMD_OPENCODE} --dir' "$SCRIPT" 2>/dev/null || true)
assert_eq "$open_code_usage" "$open_code_with_dir" \
    "Every CMD_OPENCODE usage includes --dir ($open_code_usage instances)"

master_usage=$(grep -c '\${CMD_MASTER}' "$SCRIPT" 2>/dev/null || true)
master_with_dir=$(grep -c '\${CMD_MASTER} --dir' "$SCRIPT" 2>/dev/null || true)
assert_eq "$master_usage" "$master_with_dir" \
    "Every CMD_MASTER usage includes --dir ($master_usage instances)"

# Main should call launch_opencode_daemon
assert_contains "$(declare -f main)" "launch_opencode_daemon" \
    "main calls launch_opencode_daemon"

# Final output includes new-session template
assert_contains "$(declare -f main)" "New opencode session" \
    "main prints new session instructions"

# Final output includes daemon kill command
assert_contains "$(declare -f main)" "Kill daemon" \
    "main prints daemon kill instructions"

echo ""

# Constants
assert_eq "15" "$SESSION_READY_TIMEOUT" "SESSION_READY_TIMEOUT is 15"
assert_eq "floorp" "$FLOORP_BIN" "FLOORP_BIN defaults to floorp"
assert_eq "4" "$FLOORP_WAIT" "FLOORP_WAIT is 4"

rm -f "$test_wrapper"

echo ""

# ── Summary ──────────────────────────────────────────────────────────

echo "=== Results ==="
printf '  %s passed, %s failed\n' "$PASS" "$FAIL"
if (( FAIL > 0 )); then
    exit 1
fi
