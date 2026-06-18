# A-semantika-nodo-aldoni.bash — Bugs found & fixed (2026-06-12)

## Bug 1: Malformed POSIX character class in `node_id()`

**File**: `super-bash/functions/A-semantika-nodo-aldoni.bash`
**Line**: 14
**Issue**: `[![:space]]` → missing trailing colon. Should be `[![:space:]]`.

`[:space]` (without second colon) is NOT a POSIX class — it matches literal characters `:`, `s`, `p`, `a`, `c`, `e`. The inverted bracket `[!...]` never matches normal text, causing `${s##*[![:space]]}` to return the full string, then `${s%"fullstring"}` removes everything → **empty output**.

**Fix**: `[![:space]]` → `[![:space:]]`

## Bug 2: Function name mismatch

**Line 54** (def): `command_node_id()`  
**Line 142** (call): `_command_node_id()`  

Called via `snac()`, always failed with "command not found".

**Fix**: Renamed definition to `_command_node_id()` + improved pattern from fragile delimiter set to `${1%%[[:space:]]*}` (first-word extraction, idiomatic bash).

## Docstrings added

- File-level header: requires `A semantika nodo aldoni` CLI from A-semantika package
- Per-function docs for all 12 public/private functions
- Notes: bash `node_id()` uses manual sed (Latin + Esperanto only); full Unicode via Python NFKD in A-semantika CLI

## Issues created & closed

- #1: Malformed POSIX character class
- #2: Function name mismatch

## Commit

c5991aa — pushed to main, issues closed.
