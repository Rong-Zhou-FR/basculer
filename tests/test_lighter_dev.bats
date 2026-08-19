#!/usr/bin/env bash
#
# Tests for ronWorkspace/lighter-dev.bash
#
# These are standalone bash tests (no test framework dependency).
# Run: bash tests/test_lighter_dev.bats
#
# Covers:
#   - --help exits 0 and shows documentation
#   - --dry-run exits 0 and shows preview (works without opencode on PATH)
#   - launch_term is defined with correct signature
#   - launch_term uses delete-wait loop (poll list-sessions after delete-session)
#   - launch_term filters EXITED sessions from readiness check
#   - launch_term probes action-readiness via query-tab-names
#   - Workspace registry: WORKSPACE_ITEMS, _ws_label, _prompt_selection, should_launch
#   - _run_* functions for each workspace item
#   - Floorp is a workspace item (ws_floorp), launched early if selected
#   - OpenCode daemon starts only when selected items need opencode
#   - _cleanup_opencode_daemon keeps in-use servers, asks y/N before restart
#   - _opencode_daemon_in_use detects attached clients via ESTAB connections
#   - launch_opencode_daemon reuses a server kept by cleanup
#   - _item_needs_opencode correctly identifies opencode items
#   - Every CMD_OPENCODE / CMD_MASTER usage includes --dir
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

assert_not_contains() {
    local haystack="$1" needle="$2" msg="$3"
    if [[ "$haystack" != *"$needle"* ]]; then
        green "  PASS  $msg"
        PASS=$((PASS + 1))
    else
        red "  FAIL  $msg"
        printf '    expected NOT to contain: %s\n' "$needle"
        FAIL=$((FAIL + 1))
    fi
}

# ── Test: --help ─────────────────────────────────────────────────────

echo "=== --help ==="
help_out=$(bash "$SCRIPT" --help 2>&1)
assert_eq "0" "$?" "--help exit code"
assert_contains "$help_out" "lighter-dev.bash" "shows script name"
assert_contains "$help_out" "Alacritty+Zellij" "describes terminal stack"
assert_contains "$help_out" "stop" "mentions stop command"
assert_contains "$help_out" "--dry-run" "mentions --dry-run flag"

echo ""

# ── Test: --dry-run ──────────────────────────────────────────────────
# NOTE: main() no longer has an unconditional need_cmd "opencode" — it
# is only checked inside launch_opencode_daemon which is guarded by
# DRY_RUN.  So --dry-run works even without opencode on PATH.

echo "=== --dry-run ==="
dry_out=$(bash "$SCRIPT" --dry-run 2>&1)
assert_eq "0" "$?" "--dry-run exit code"
assert_contains "$dry_out" "Floorp" "mentions Floorp browser"
assert_contains "$dry_out" "lighter-config" "mentions workspace tabs"
assert_contains "$dry_out" "nvim README.md" "shows commands"
assert_contains "$dry_out" "opencode" "shows all workspaces"
assert_contains "$dry_out" "classroomioplus" "mentions WS5 classroomioplus item"

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

# launch_term no longer has a broken setsid-wrapper PID check
assert_not_contains "$(declare -f launch_term)" "alacritty_pid" \
    "launch_term does not capture alacritty PID (setsid wrapper is unreliable)"
assert_not_contains "$(declare -f launch_term)" "Alacritty exited immediately" \
    "launch_term does not have broken early-exit check for alacritty"

# launch_term has idempotent check (skip if already active)
assert_contains "$(declare -f launch_term)" "already active — skipping" \
    "launch_term skips existing active sessions (idempotent)"

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
# restore_floorp should NOT use $! for floorp PID (setsid wrapper is wrong)
assert_contains "$(declare -f restore_floorp)" 'floorp_pid_new="$(' \
    "restore_floorp uses pgrep for post-launch PID check (not \$!)"
assert_not_contains "$(declare -f restore_floorp)" "kill -0" \
    "restore_floorp does not use kill -0 on setsid-wrapper PID"

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
assert_contains "$(declare -f launch_opencode_daemon)" "ss -tlnp" \
    "launch_opencode_daemon polls ss for port binding"
assert_not_contains "$(declare -f launch_opencode_daemon)" "/global/health" \
    "launch_opencode_daemon no longer polls HTTP health"
assert_not_contains "$(declare -f launch_opencode_daemon)" "curl -sf" \
    "launch_opencode_daemon no longer uses curl for health check"
assert_contains "$(declare -f launch_opencode_daemon)" "systemd-run" \
    "launch_opencode_daemon uses systemd-run for process lifecycle"
assert_contains "$(declare -f launch_opencode_daemon)" "PID_FILE" \
    "launch_opencode_daemon stores PID in PID_FILE"
assert_contains "$(declare -f launch_opencode_daemon)" "OPCODE_DAEMON_TIMEOUT" \
    "launch_opencode_daemon uses OPCODE_DAEMON_TIMEOUT for polling"

# _cleanup_opencode_daemon must never blindly kill a running server
assert_contains "$(declare -f _cleanup_opencode_daemon)" "Restart it? [y/N]" \
    "_cleanup_opencode_daemon asks y/N before restarting an idle server"
assert_contains "$(declare -f _cleanup_opencode_daemon)" "in use by attached session" \
    "_cleanup_opencode_daemon keeps a server with attached sessions without asking"
assert_contains "$(declare -f _cleanup_opencode_daemon)" "OPCODE_DAEMON_ALREADY_RUNNING" \
    "_cleanup_opencode_daemon marks a kept server for reuse"
assert_contains "$(declare -f _cleanup_opencode_daemon)" "ss -tlnp" \
    "_cleanup_opencode_daemon polls ss for port"
assert_contains "$(declare -f _cleanup_opencode_daemon)" "forcing" \
    "_cleanup_opencode_daemon force-kills after timeout (when restart confirmed)"
assert_not_contains "$(declare -f _cleanup_opencode_daemon)" "Stopping existing OpenCode server" \
    "_cleanup_opencode_daemon no longer kills an existing server unconditionally"

# _opencode_daemon_in_use — attached-client detection via ESTAB connections
assert_contains "$(declare -f _opencode_daemon_in_use)" 'dport = :${OPCODE_SERVE_PORT}' \
    "_opencode_daemon_in_use filters established connections to the server port"
assert_contains "$(declare -f _opencode_daemon_in_use)" "sample1" \
    "_opencode_daemon_in_use takes a first connection sample"
assert_contains "$(declare -f _opencode_daemon_in_use)" "sample2" \
    "_opencode_daemon_in_use takes a second connection sample"
assert_contains "$(declare -f _opencode_daemon_in_use)" "grep -o 'pid=" \
    "_opencode_daemon_in_use extracts foreign PIDs from ss output"

# launch_opencode_daemon reuses a server kept by cleanup
assert_contains "$(declare -f launch_opencode_daemon)" "OPCODE_DAEMON_ALREADY_RUNNING" \
    "launch_opencode_daemon reuses an existing server instead of starting a new one"

# CMD_OPENCODE uses attach mode
assert_contains "${CMD_OPENCODE}" "opencode attach" \
    "CMD_OPENCODE uses opencode attach"
assert_contains "${CMD_OPENCODE}" "${OPCODE_SERVE_URL}" \
    "CMD_OPENCODE references OPCODE_SERVE_URL"

# CMD_MASTER uses attach --mini (run doesn't support --mini)
assert_contains "${CMD_MASTER}" "opencode attach" \
    "CMD_MASTER uses opencode attach"
assert_contains "${CMD_MASTER}" "--mini" \
    "CMD_MASTER uses --mini"
assert_contains "${CMD_MASTER}" "${OPCODE_SERVE_URL}" \
    "CMD_MASTER references OPCODE_SERVE_URL"

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

# Main should call launch_opencode_daemon (conditionally)
assert_contains "$(declare -f main)" "launch_opencode_daemon" \
    "main calls launch_opencode_daemon"

# Main calls preemptive cleanup unconditionally
assert_contains "$(declare -f main)" "_cleanup_opencode_daemon" \
    "main calls _cleanup_opencode_daemon unconditionally"

# Final output includes new-session template
assert_contains "$(declare -f main)" "New opencode session" \
    "main prints new session instructions"

# Final output includes daemon kill command
assert_contains "$(declare -f main)" "Kill daemon" \
    "main prints daemon kill instructions"

# ── Test: stop command ────────────────────────────────────────────────

echo "=== stop ==="

# _graceful_stop helper (SIGTERM → wait → SIGKILL)
assert_contains "$(declare -f _graceful_stop)" "kill -9" \
    "_graceful_stop escalates to SIGKILL after timeout"
assert_contains "$(declare -f _graceful_stop)" 'kill "$pid"' \
    "_graceful_stop sends SIGTERM first (graceful)"
assert_contains "$(declare -f _graceful_stop)" 'ps -p "$pid"' \
    "_graceful_stop polls process existence"

# _stop_workspace function exists and covers all started processes
assert_contains "$(declare -f _stop_workspace)" "lighter-dev-" \
    "_stop_workspace targets lighter-dev-* sessions"
assert_contains "$(declare -f _stop_workspace)" "delete-session --force" \
    "_stop_workspace uses delete-session --force"
assert_contains "$(declare -f _stop_workspace)" "systemctl --user stop opencode-serve" \
    "_stop_workspace stops opencode daemon via systemd"
assert_contains "$(declare -f _stop_workspace)" "desktop-plus" \
    "_stop_workspace stops desktop-plus"
assert_contains "$(declare -f _stop_workspace)" "OPCODE_SERVE_PORT" \
    "_stop_workspace references OPCODE_SERVE_PORT"
assert_contains "$(declare -f _stop_workspace)" "Floorp browser" \
    "_stop_workspace closes Floorp browser"

# _stop_workspace uses _graceful_stop for graceful termination
assert_contains "$(declare -f _stop_workspace)" "_graceful_stop" \
    "_stop_workspace uses _graceful_stop helper"

# main() dispatches stop
assert_contains "$(declare -f main)" "stop | --stop" \
    "main handles stop | --stop arguments"
assert_contains "$(declare -f main)" "_stop_workspace" \
    "main calls _stop_workspace for stop"

echo ""

# ── Test: workspace registry ────────────────────────────────────────────

echo "=== workspace registry ==="

# _WS_IDS should have 13 entries (floorp + 11 workspace terminals/GUIs + oc_server)
assert_eq "13" "${#_WS_IDS[@]}" \
    "_WS_IDS has 13 entries"

# _WS_NEEDS_OPENCODE should be same length (parallel array)
assert_eq "${#_WS_IDS[@]}" "${#_WS_NEEDS_OPENCODE[@]}" \
    "_WS_NEEDS_OPENCODE is parallel to _WS_IDS"

# Every _WS_IDS entry has a label via _ws_label
_ws_test_all_labeled=true
for ((_ws_test_i=0; _ws_test_i<${#_WS_IDS[@]}; _ws_test_i++)); do
    _ws_test_label="$(_ws_label "${_WS_IDS[_ws_test_i]}")"
    if [[ "$_ws_test_label" == UNKNOWN:* ]]; then
        _ws_test_all_labeled=false
        echo "  MISSING LABEL: ${_WS_IDS[_ws_test_i]}" >&2
    fi
done
assert_eq "true" "$_ws_test_all_labeled" \
    "Every _WS_IDS entry has a _ws_label"

# _WS_IDS includes classroomioplus and floorp
assert_contains "${_WS_IDS[*]}" "ws5_classroomioplus" \
    "_WS_IDS includes ws5_classroomioplus"
assert_contains "${_WS_IDS[*]}" "ws_floorp" \
    "_WS_IDS includes ws_floorp"

# _WS_NEEDS_OPENCODE metadata is correct (check by iterating)
_oc_all_correct=true
for ((_ws_test_i=0; _ws_test_i<${#_WS_IDS[@]}; _ws_test_i++)); do
    _ws_test_id="${_WS_IDS[_ws_test_i]}"
    _ws_test_meta="${_WS_NEEDS_OPENCODE[_ws_test_i]}"
    case "$_ws_test_id" in
        ws4_basculer|ws5_lbgm|ws5_smgm|ws5_rzdoi|ws5_classroomioplus|ws12_fec|oc_server)
            [[ "$_ws_test_meta" == "true" ]] || _oc_all_correct=false ;;
        *)
            [[ "$_ws_test_meta" == "false" ]] || _oc_all_correct=false ;;
    esac
done
assert_eq "true" "$_oc_all_correct" \
    "_WS_NEEDS_OPENCODE metadata is correct for all items"

# _run_ws5_classroomioplus defined and uses CMD_MASTER + CMD_OPENCODE
assert_contains "$(declare -f _run_ws5_classroomioplus)" "CMD_MASTER" \
    "_run_ws5_classroomioplus uses CMD_MASTER for gitmaster tab"
assert_contains "$(declare -f _run_ws5_classroomioplus)" "CMD_OPENCODE" \
    "_run_ws5_classroomioplus uses CMD_OPENCODE for opencode tab"
assert_contains "$(declare -f _run_ws5_classroomioplus)" "DIR_CLASSROOMIOPLUS" \
    "_run_ws5_classroomioplus references DIR_CLASSROOMIOPLUS"

# _run_ws_floorp calls restore_floorp
assert_contains "$(declare -f _run_ws_floorp)" "restore_floorp" \
    "_run_ws_floorp calls restore_floorp"

# oc_server — server-only option (no terminal clients)
assert_contains "${_WS_IDS[*]}" "oc_server" \
    "_WS_IDS includes oc_server (server-only option)"
assert_contains "$(declare -f _run_oc_server)" "OPCODE_SERVE_URL" \
    "_run_oc_server references OPCODE_SERVE_URL"
assert_contains "$(declare -f _run_oc_server)" "no clients" \
    "_run_oc_server states it starts no clients"

# _run_workspace_item uses dynamic dispatch (no case statement)
assert_contains "$(declare -f _run_workspace_item)" '"_run_${id}"' \
    "_run_workspace_item uses dynamic dispatch"
assert_not_contains "$(declare -f _run_workspace_item)" "_run_ws_floorp" \
    "_run_workspace_item no longer hardcodes function names"

# Main has conditional daemon logic
assert_contains "$(declare -f main)" "_needs_opencode" \
    "main checks _needs_opencode before launching daemon"
assert_contains "$(declare -f main)" 'should_launch 1' \
    "main checks should_launch 1 before restoring floorp"
assert_contains "$(declare -f main)" '_WS_NEEDS_OPENCODE' \
    "main reads _WS_NEEDS_OPENCODE metadata"

# should_launch works
SELECTED_ITEMS="__ALL__"
_ws_exit=0
should_launch 1 || _ws_exit=$?
assert_eq "0" "$_ws_exit" \
    "should_launch returns 0 (true) when SELECTED_ITEMS=__ALL__"
SELECTED_ITEMS="2 4 6"
_ws_exit=0
should_launch 2 || _ws_exit=$?
assert_eq "0" "$_ws_exit" \
    "should_launch returns 0 for selected item"
_ws_exit=0
should_launch 3 || _ws_exit=$?
assert_eq "1" "$_ws_exit" \
    "should_launch returns 1 for unselected item"

# _prompt_selection function exists (tested structurally only; interactive use via main)
assert_contains "$(declare -f _prompt_selection)" "read -r" \
    "_prompt_selection uses read for interactive input"

echo ""

# Constants
assert_eq "15" "$SESSION_READY_TIMEOUT" "SESSION_READY_TIMEOUT is 15"
assert_eq "floorp" "$FLOORP_BIN" "FLOORP_BIN defaults to floorp"
assert_eq "10" "$FLOORP_WAIT" "FLOORP_WAIT is 10"
assert_eq "30" "$OPCODE_DAEMON_TIMEOUT" "OPCODE_DAEMON_TIMEOUT is 30"

rm -f "$test_wrapper"

echo ""

# ── Summary ──────────────────────────────────────────────────────────

echo "=== Results ==="
printf '  %s passed, %s failed\n' "$PASS" "$FAIL"
if (( FAIL > 0 )); then
    exit 1
fi
