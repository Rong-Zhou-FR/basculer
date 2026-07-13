---
description: Identify stale, merged, and WIP branches, classify them safely, and present findings for human direction before taking any action.
agent: copilot
---

# Branch Cleanup

**Never delete or merge branches without explicit human confirmation.** The AI classifies and recommends — the human decides.

## Phase 1 — Discover & Classify

Identify all local and remote tracking branches (excluding `main`, `master`, `develop`, and `HEAD`). For each branch, determine:

| Attribute | How to check |
|-----------|-------------|
| Merged into `main`? | `git branch --merged main` (local), or check if all commits are reachable from `main` |
| Last commit date | `git for-each-ref --format='%(committerdate:unix)' refs/heads/<branch>` |
| Uncommitted changes? | `git status --porcelain` on the branch (switch briefly or check `git stash list` for branch-specific stashes) |
| Unpushed commits? | `git log origin/main..<branch>` or `git log --oneline <branch> --not origin/main` |
| Clean merge? | `git merge-base --is-ancestor <branch> main` + try `git merge --no-commit --no-ff` (dry run, then `abort`) |
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

Also run `git stash list`. Stashes aren't per-branch, but flag them as potential WIP if there's anything in the stash.

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

REMOTE_ONLY (no local branch):
  origin/chore/dedup-agent-security-sections   merged → safe to delete remote
  origin/feat/remove-context-mode              3wk old, unmerged → what to do?
```

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

## Safety Rules (hard)

1. **Never auto-delete.** Always present and wait for explicit human instruction.
2. **Always tag before delete.** No exceptions.
3. **Never use `git branch -D` (force delete).** Use `-d`; if git refuses because the branch isn't fully merged, report to human rather than forcing.
4. **Never auto-merge.** Only merge branches the human explicitly names.
5. **Never resolve merge conflicts.** If a merge conflicts, stop and present to human.
6. **Never push backup tags.** Backup tags are local-only. Do not `git push --tags` during cleanup.
7. **If in doubt, ask.** If a branch doesn't fit cleanly into any category, flag it and let the human decide.

Follow conventions in AGENTS.md.
