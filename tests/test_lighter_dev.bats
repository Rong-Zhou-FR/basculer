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
#   - gen_layout produces valid KDL with correct tab names, cwds, commands
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

# ── Test: gen_layout ─────────────────────────────────────────────────

echo "=== gen_layout ==="

# We need to source the function definitions without calling main.
# Create a slim wrapper that sources everything except the last line.
test_wrapper=$(mktemp)
# Remove the trailing `main "$@"` line so we can safely source
sed '/^main "\$@"$/d' "$SCRIPT" > "$test_wrapper"

# Wrapper must not error out from set -euo pipefail when we don't call main
printf '\n# override: gen_layout tests only — do not call main\ntrue\n' >> "$test_wrapper"

source "$test_wrapper"

# Test 1: Shell-only tabs
gen_layout /tmp/test_l1.kdl \
    "tab1|/home/user/proj|" \
    "tab2|/home/user/other|"

l1=$(cat /tmp/test_l1.kdl)
assert_contains "$l1" 'tab name="tab1" cwd="/home/user/proj"' "tab1 name+cwd"
assert_contains "$l1" 'tab name="tab2" cwd="/home/user/other"' "tab2 name+cwd"
assert_contains "$l1" 'pane' "shell-only tab has pane"
assert_contains "$l1" 'layout {' "starts with layout"
assert_contains "$l1" '}' "ends with closing brace"
rm -f /tmp/test_l1.kdl

# Test 2: Command tabs
gen_layout /tmp/test_l2.kdl \
    "code|/home/user/proj|nvim README.md"

l2=$(cat /tmp/test_l2.kdl)
assert_contains "$l2" 'command="bash"' "command tab uses bash"
assert_contains "$l2" 'nvim README.md; exec bash' "command wrapping preserves original cmd"
rm -f /tmp/test_l2.kdl

# Test 3: Mixed shell + command tabs
gen_layout /tmp/test_l3.kdl \
    "shell|/tmp|" \
    "build|/tmp|make" \
    "edit|/tmp|vim"

l3=$(cat /tmp/test_l3.kdl)
# Should have 3 tab declarations
tab_count=$(grep -c 'tab name=' /tmp/test_l3.kdl || true)
assert_eq "3" "$tab_count" "mixed layout has 3 tabs"
rm -f /tmp/test_l3.kdl

# Test 4: Directory escaping (spaces, special chars)
gen_layout /tmp/test_l4.kdl \
    "my code|/home/user/my projects|"

l4=$(cat /tmp/test_l4.kdl)
assert_contains "$l4" 'cwd="/home/user/my projects"' "escapes spaces in cwd"
rm -f /tmp/test_l4.kdl

# Clean up
rm -f "$test_wrapper"

echo ""

# ── Summary ──────────────────────────────────────────────────────────

echo "=== Results ==="
printf '  %s passed, %s failed\n' "$PASS" "$FAIL"
if (( FAIL > 0 )); then
    exit 1
fi
