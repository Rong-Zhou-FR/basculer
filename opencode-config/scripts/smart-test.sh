#!/usr/bin/env bash
# smart-test.sh — shared smart test runner for lighter-system projects.
#
# Sources this from a project's scripts/test.sh after setting these env vars:
#
#   ROOT                  — project root (set by wrapper)
#   FRONTEND_PATTERNS     — globs for frontend files (space-separated)
#   BACKEND_PATTERNS      — globs for backend files
#   META_PATTERNS         — globs for meta/script files
#
# Optional:
#   FRONTEND_BUILD_DIR    — subdirectory for the frontend (default: "web")
#   FRONTEND_BUILD_CMD    — build command (default: "npm run build")
#   VITEST_DIR            — subdirectory for vitest (default: "web")
#   VITEST_CMD            — vitest command (default: "npm run test")
#
# Example wrapper (lighterbird/scripts/test.sh):
#
#   #!/usr/bin/env bash
#   set -euo pipefail
#   ROOT="$(cd "$(dirname "$0")/.." && pwd)"
#   FRONTEND_PATTERNS="web/*"
#   BACKEND_PATTERNS="src/*.py tests/*.py pyproject.toml"
#   source /home/rongzhou/kodo/basculer/opencode-config/scripts/smart-test.sh
#
# ---

set -euo pipefail

# ── Validate required vars ──────────────────────────────────────────────
: "${ROOT:?smart-test.sh: ROOT must be set by wrapper}"
: "${FRONTEND_PATTERNS:?smart-test.sh: FRONTEND_PATTERNS must be set}"
: "${BACKEND_PATTERNS:?smart-test.sh: BACKEND_PATTERNS must be set}"
: "${META_PATTERNS:?smart-test.sh: META_PATTERNS must be set}"

# ── Defaults ─────────────────────────────────────────────────────────────
FRONTEND_BUILD_DIR="${FRONTEND_BUILD_DIR:-web}"
FRONTEND_BUILD_CMD="${FRONTEND_BUILD_CMD:-npm run build}"
VITEST_DIR="${VITEST_DIR:-web}"
VITEST_CMD="${VITEST_CMD:-npm run test}"

# ── Resolve main checkout paths (for worktree support) ───────────────────
MAIN_DIR=""
if git -C "$ROOT" rev-parse --is-inside-work-tree 2>/dev/null | grep -q true; then
    GIT_COMMON_DIR=$(cd "$ROOT" && git rev-parse --git-common-dir 2>/dev/null)
    if [ -n "$GIT_COMMON_DIR" ]; then
        MAIN_DIR=$(cd "$GIT_COMMON_DIR/.." && pwd)
    fi
fi

# ── Detect what changed vs HEAD ──────────────────────────────────────────
HAS_FRONTEND=false
HAS_BACKEND=false
HAS_META=false

CHANGED_FILES=""
if git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    CHANGED_FILES=$(git -C "$ROOT" diff --name-only HEAD 2>/dev/null || true)
    CHANGED_FILES="$CHANGED_FILES"$'\n'"$(git -C "$ROOT" ls-files --others --exclude-standard 2>/dev/null || true)"
fi

while IFS= read -r f; do
    [ -z "$f" ] && continue
    for pat in $FRONTEND_PATTERNS; do
        case "$f" in $pat) HAS_FRONTEND=true ;; esac
    done
    for pat in $BACKEND_PATTERNS; do
        case "$f" in $pat) HAS_BACKEND=true ;; esac
    done
    for pat in $META_PATTERNS; do
        case "$f" in $pat) HAS_META=true ;; esac
    done
done <<< "$CHANGED_FILES"

# ── Determine what to run ────────────────────────────────────────────────
RUN_FRONTEND=false
RUN_PYTEST=false

if [ $# -gt 0 ]; then
    RUN_PYTEST=true
    if $HAS_FRONTEND || $HAS_META; then
        RUN_FRONTEND=true
    fi
else
    if $HAS_FRONTEND || $HAS_META; then  RUN_FRONTEND=true;  fi
    if $HAS_BACKEND || $HAS_META;  then  RUN_PYTEST=true;    fi
    if ! $RUN_FRONTEND && ! $RUN_PYTEST; then
        RUN_FRONTEND=true;  RUN_PYTEST=true
    fi
fi

echo "[test.sh] changed: frontend=$HAS_FRONTEND backend=$HAS_BACKEND meta=$HAS_META" >&2
echo "[test.sh] running: frontend_build=$RUN_FRONTEND pytest=$RUN_PYTEST" >&2

# ── Frontend build (a11y gate) ───────────────────────────────────────────
_run_frontend() {
    local dir="$ROOT/$FRONTEND_BUILD_DIR"
    if [ ! -d "$dir" ]; then
        echo "[test.sh] WARNING: $FRONTEND_BUILD_DIR/ not found — skipping frontend build" >&2
        return
    fi

    # Resolve vite binary — try local, then main checkout fallback
    local vite_bin="$dir/node_modules/.bin/vite"
    if [ ! -x "$vite_bin" ] && [ -n "$MAIN_DIR" ]; then
        vite_bin="$MAIN_DIR/$FRONTEND_BUILD_DIR/node_modules/.bin/vite"
    fi

    if [ -x "$vite_bin" ]; then
        # Use a subshell so the cd doesn't affect the caller
        (cd "$dir" && NODE_PATH="" "$vite_bin" build) 2>&1 || {
            echo "[test.sh] Frontend build FAILED — check a11y violations above" >&2
            exit 1
        }
    else
        # Fallback: run the configured build command
        (cd "$dir" && $FRONTEND_BUILD_CMD) 2>&1 || {
            echo "[test.sh] Frontend build FAILED — check errors above" >&2
            exit 1
        }
    fi
}

_run_vitest() {
    local dir="$ROOT/$VITEST_DIR"
    if [ ! -d "$dir" ]; then
        echo "[test.sh] WARNING: $VITEST_DIR/ not found — skipping vitest" >&2
        return
    fi
    (cd "$dir" && $VITEST_CMD) 2>&1 || {
        echo "[test.sh] Vitest FAILED" >&2
        exit 1
    }
}

_run_pytest() {
    local venv_python=""
    if [ -n "$MAIN_DIR" ]; then
        venv_python="$MAIN_DIR/.venv/bin/python"
    fi

    if [ -n "$venv_python" ] && [ -x "$venv_python" ]; then
        echo "[test.sh] Worktree detected — using $MAIN_DIR/.venv" >&2
        PYTHONPATH="$ROOT/src" exec "$venv_python" -m pytest "$@"
    fi
    # Fallback: direct invocation
    exec python -m pytest "$@"
}

# ── Execute ──────────────────────────────────────────────────────────────
if $RUN_FRONTEND; then
    echo "[test.sh] Building frontend (a11y gate)..." >&2
    _run_frontend
else
    echo "[test.sh] No frontend changes detected — skipping frontend build" >&2
fi

if $RUN_PYTEST; then
    _run_pytest "$@"
else
    echo "[test.sh] No backend changes detected — skipping pytest" >&2
fi
