#!/usr/bin/env bash
# migrate-serena-memories.sh — COPY serena memories into Gortex
#
# Usage: run AFTER gortex daemon is running and repos are tracked.
# Copies (not moves) so serena memories remain intact as fallback.
#
# Requires: gortex (daemon running), jq, find

set -euo pipefail

SERENA_MEM_DIR="$HOME/.serena/memories"
LOG_FILE="/tmp/gortex-memory-migration.log"
: > "$LOG_FILE"

log_info() { printf '\e[34m[INFO]\e[0m  %s\n' "$*"; }
log_ok()  { printf '\e[32m[OK]\e[0m    %s\n' "$*"; }
log_warn(){ printf '\e[33m[WARN]\e[0m  %s\n' "$*"; }
log_err() { printf '\e[31m[ERROR]\e[0m %s\n' "$*" >&2; }

# ── Checks ────────────────────────────────────────────────────────────────

if ! command -v gortex &>/dev/null; then
  log_err "gortex not found on PATH."
  exit 1
fi

if ! command -v jq &>/dev/null; then
  log_err "jq not found on PATH (required for JSON payload construction)."
  exit 1
fi

if ! gortex daemon status &>/dev/null; then
  log_err "gortex daemon is not running. Start it with: gortex daemon start --detach"
  exit 1
fi

if [[ ! -d "$SERENA_MEM_DIR" ]]; then
  log_err "Serena memories directory not found: $SERENA_MEM_DIR"
  exit 1
fi

# ── Stats ─────────────────────────────────────────────────────────────────

total=0
migrated=0
skipped=0
errors=0

# ── Migration function ────────────────────────────────────────────────────
# Uses `gortex call store_memory` via JSON payload from stdin.
# We derive: title from filename path, kind=reference, importance=3,
# confidence=1, tags=["serena-migration","global"], scope=global.

migrate_memory() {
  local file="$1"
  local rel_path="${file#$SERENA_MEM_DIR/}"
  # Build a flat title from the relative path
  local title="${rel_path%.md}"
  # Replace / with — for readable titles
  title="${title//\// — }"

  local kind="reference"
  local importance=3
  local confidence=1

  # Build JSON payload
  local payload
  payload=$(jq -n \
    --arg name "$title" \
    --arg title "$title" \
    --arg body_content "$(cat "$file")" \
    --arg kind "$kind" \
    --argjson importance "$importance" \
    --argjson confidence "$confidence" \
    --arg tags "serena-migration,global" \
    '{
      name: $name,
      title: $title,
      body: $body_content,
      kind: $kind,
      importance: $importance,
      confidence: $confidence,
      tags: [$tags | split(",")[]],
      scope: "global",
      source: "manual"
    }')

  # Store via gortex call
  if echo "$payload" | gortex call store_memory --json - --format json &>> "$LOG_FILE"; then
    log_ok "migrated: $rel_path"
    return 0
  else
    log_warn "FAILED: $rel_path (see $LOG_FILE)"
    return 1
  fi
}

# ── Main ──────────────────────────────────────────────────────────────────

log_info "Migrating serena memories from $SERENA_MEM_DIR"
log_info "Log: $LOG_FILE"
echo ""

# Count total
total=$(find "$SERENA_MEM_DIR" -name "*.md" -type f | wc -l)
log_info "Found $total memory files to migrate"
echo ""

# Migrate each file
while IFS= read -r -d '' file; do
  if migrate_memory "$file"; then
    migrated=$((migrated + 1))
  else
    errors=$((errors + 1))
  fi
done < <(find "$SERENA_MEM_DIR" -name "*.md" -type f -print0)

# ── Summary ───────────────────────────────────────────────────────────────
echo ""
log_info "Migration complete:"
log_info "  Total:   $total"
log_info "  Success: $migrated"
if (( errors > 0 )); then
  log_warn "  Errors:  $errors (see $LOG_FILE for details)"
fi
log_info ""
log_info "Verify with: gortex call recall --arg query='serena' --arg tag='serena-migration'"
log_info "serena memories remain untouched at $SERENA_MEM_DIR"
