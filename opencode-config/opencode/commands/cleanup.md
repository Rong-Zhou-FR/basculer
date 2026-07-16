---
description: Identify stale, merged, and WIP branches, classify them safely, and present findings for human direction before taking any action.
agent: copilot
---

# Branch Cleanup

**Never delete or merge branches without explicit human confirmation.** The AI classifies and recommends — the human decides.

## Phase 0 — Working Tree Safety

Before touching branches, protect any in-progress work on the current working tree:

```bash
# Save dirty working tree state (uncommitted changes + untracked files)
if ! git diff --quiet --exit-code || ! git diff --cached --quiet --exit-code; then
  git stash push --include-untracked --message "opencode-cleanup/auto-stash: pre-cleanup $(date +%F-%H%M)"
  echo "Working tree stashed (will restore at end)."
fi
```

This ensures `git checkout` operations in later phases never fail due to local edits. The stash message includes a `opencode-cleanup/auto-stash:` prefix so it's distinguishable from human-made stashes. Save the ref (`stash@{0}`) if you need to restore later.

## Phase 1 — Discover & Classify

Identify all local and remote tracking branches (excluding `main`, `master`, `develop`, and `HEAD`). For each branch, determine:

| Attribute | How to check |
|-----------|-------------|
| Merged into `main`? | `git branch --merged main` (local), or check if all commits are reachable from `main`. **Warning:** squash/rebase merges are invisible to ancestry checks — `--merged` will say "no" even if the branch was merged. |
| Last commit date | `git for-each-ref --format='%(committerdate:unix)' refs/heads/<branch>` |
| Uncommitted changes? | `git status --porcelain` on the branch (switch briefly or check `git stash list` for branch-specific stashes) |
| Unpushed commits? | `git log origin/main..<branch>` or `git log --oneline <branch> --not origin/main` |
| Clean merge? | Tier 1: `git merge-base --is-ancestor <branch> main` (regular merges). Tier 2: `git diff --quiet main..<branch>` (squash/rebase — exits 0 if trees identical). **Tier 3 (hint, not proof):** `git log main --oneline --grep="$(git log -1 --format='%s' <branch>)"` — if the branch tip commit message appears in `main`'s log, the branch was likely squash-merged. If all three fail, merge is not detectable programmatically — ask user to confirm, then tag-before-delete. |
| Remote counterpart exists? | `git branch -r` contains `origin/<branch>` |

Classify each branch into one of:

| Category | Label | Criterion |
|----------|-------|-----------|
| **Safe to delete** | `DELETE_SAFE` | Merged into `main` AND no unpushed commits AND no uncommitted changes |
| **Stale** | `STALE` | Not merged AND last commit >30 days ago |
| **Merge-clean** | `MERGE_CLEAN` | Not merged AND merges into `main` without conflict |
| **Merge-conflict** | `MERGE_CONFLICT` | Not merged AND `git merge --no-commit --no-ff` produces conflicts |
| **Work-in-progress** | `WIP` | Has uncommitted changes OR unpushed commits (regardless of merge status) |
| **Remote-only** | `REMOTE_ONLY` | Exists only on `origin/` with no local counterpart |

### Stash-to-Branch Correlation

`git stash list` records the originating branch in each stash message (`WIP on <branch>: <commit> <message>`). Parse this to produce a stash-per-branch map:

```bash
git stash list --format="%gd: %gs" | while IFS=': ' read -r ref msg; do
  # Extract branch from "WIP on feat/foo: abc1234 commit message"
  branch=$(echo "$msg" | sed -n 's/^WIP on $[^:]*$:.*/\1/p')
  echo "$branch -> $ref"
done
```

Include this map in the report. Stashes tied to a branch in the `DELETE_SAFE` or `MERGE_CLEAN` categories must be surfaced to the human before any action is taken:

> **Stash warning**: `feat/foo` has 2 stashes (`stash@{2}`, `stash@{3}`). Deleting this branch orphans those stashes — they remain in the reflog but lose their branch context. The backup tag preserves the commit graph, making recovery via `git stash pop` still possible.

Do **not** automatically pop or drop stashes. Always flag and let the human decide.

Flag the auto-stash from Phase 0 if present (it has the `opencode-cleanup/auto-stash:` prefix) — exclude it from per-branch correlation since it belongs to the working tree, not a feature branch.

## Phase 2 — Present Findings

Present a table with all branches, their classification, and a recommendation. 

```
Branch Cleanup Report — <repo name> (generated <date>)
═════════════════════════════════════════════════════════

DELETE_SAFE (tag → delete):
  feat/port-process-ownership   merged 6d ago   → delete
  feat/record-pid-pattern       merged 6d ago   → delete

STALE (>30d without activity):
  (none)

MERGE_CLEAN (merge into main, no conflicts):
  (none)

MERGE_CONFLICT (needs human resolution):
  feat/big-refactor             unmerged, conflicts on src/foo.py

WIP (has uncommitted/unpushed work):
  feat/local-experiment         2 unpushed commits, 3 unstaged files

STASHED (has orphaned stashes — warn before delete):
  feat/draft-widget             stash@{2}, stash@{3}   → 2 stashes will lose context
  refactor/db-layer             stash@{5}              → 1 stash will lose context

REMOTE_ONLY (no local branch):
  origin/chore/dedup-agent-security-sections   merged → safe to delete remote
  origin/feat/remove-context-mode              3wk old, unmerged → what to do?
```

For each branch in `STASHED`, include the stash details in the report. The human must acknowledge before deletion proceeds.

Then ask user:

> **What should I do?** Reply with:
> - `delete <branch-a> <branch-b>` — I'll tag then delete each
> - `merge <branch-c>` — I'll merge into main
> - `keep <branch-d>` — leave it alone
> - `delete-remote <branch-e>` — delete a remote-only branch
> - `delete-all-safe` — execute all DELETE_SAFE recommendations
> - Abbreviated branch names are OK if unambiguous (partial match)

## Phase 3 — Execute Human Instructions

ONLY act on what the HUMAN EXPLICITLY APPROVED. Never infer intent.

### Tag-before-delete

For EVERY branch being deleted (local or remote), **first create a backup tag** pointing at the branch tip:

```bash
git tag backup/cleanup-$(date +%F)/<branch-name> <branch-name>
```

The tag name encodes:
- `backup/` — namespace to keep these separate from real tags
- `cleanup-YYYY-MM-DD/` — which operation created it
- `<branch-name>` — the original branch name (slashes work fine in tag names)

This makes recovery trivial: `git checkout -b <branch-name> backup/cleanup-<date>/<branch-name>`.

**Before deleting**: if the branch has associated stashes (from the stash-per-branch map in Phase 2), print the warning again and ask for explicit confirmation before proceeding. The backup tag preserves the commit graph, so stashes remain functional — but the human must be aware.

### Delete

```bash
# Tag first (safety)
git tag backup/cleanup-$(date +%F)/feat/port-process-ownership feat/port-process-ownership

# Delete local branch — use -d (safe), never -D (force)
git branch -d feat/port-process-ownership

# Delete remote branch — only if explicitly asked
git push origin --delete feat/port-process-ownership
```

### Delete remote-only branch

**Only** if the human said `delete-remote`:

```bash
git push origin --delete chore/dedup-agent-security-sections
```

Create local backup tag for extra safety.

### Merge

ONLY merge branches the human explicitly said `merge`. Use:

```bash
git checkout main && git pull
git merge --no-ff <branch-name>
```

If the merge produces conflicts that were not present during Phase 1 classification, **stop and report to the human** — do not resolve them yourself.

### Keep

Do nothing. Report it was skipped.

## Phase 4 — Report Outcome

After executing all approved actions, report:

```
Done. Summary:
  ✅ Deleted (with backup tags): feat/foo, feat/bar
  ✅ Merged: feat/baz
  ⏭️  Kept: feat/wip, feat/old-thing
  ❌ Skipped (conflict during merge): feat/big-refactor

Backup tags created:
  backup/cleanup-2026-07-13/feat/foo
  backup/cleanup-2026-07-13/feat/bar

To restore: git checkout -b feat/foo backup/cleanup-2026-07-13/feat/foo
To clean old backup tags later: git tag -l 'backup/cleanup-*' | xargs git tag -d
```

### Working Tree Restore

If Phase 0 stashed the working tree (look for a stash with the `opencode-cleanup/auto-stash:` prefix), restore it now:

```bash
AUTO_STASH=$(git stash list --format="%gd: %gs" | grep "opencode-cleanup/auto-stash:" | head -1 | cut -d: -f1)
if [ -n "$AUTO_STASH" ]; then
  git stash pop "$AUTO_STASH"
  echo "Working tree restored to pre-cleanup state."
fi
```

If there are merge conflicts during pop (e.g., a branch you merged changed a file you had edited locally), **stop and report to the human** — do not resolve them yourself.

## Safety Rules (hard)

1. **Never auto-delete.** Always present and wait for explicit human instruction.
2. **Always tag before delete.** No exceptions.
3. **Never use `git branch -D` (force delete).** Use `-d`; if git refuses because the branch isn't fully merged, report to human rather than forcing.
4. **Never auto-merge.** Only merge branches the human explicitly names.
5. **Never resolve merge conflicts.** If a merge conflicts, stop and present to human.
6. **Never push backup tags.** Backup tags are local-only. Do not `git push --tags` during cleanup.
7. **If in doubt, ask.** If a branch doesn't fit cleanly into any category, flag it and let the human decide.
8. **Never auto-stash without restore.** If Phase 0 stashed the working tree, Phase 4 MUST restore it. A forgotten stash is data loss.
9. **Surface stashes before delete.** If a `DELETE_SAFE` or `MERGE_CLEAN` branch has associated stashes, warn the human before proceeding. Never delete a branch with orphaned stashes without explicit acknowledgement.
10. **Never pop or drop human stashes.** The auto-stash (Phase 0) is restore-only. Human-created stashes are flagged but never touched — only the human may `git stash drop` them.

Follow conventions in AGENTS.md.
