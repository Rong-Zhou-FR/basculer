---
description: Mark a worktree for deferred cleanup (validates clean state + merged branch, then marks for cleanup). Actual deletion (remove directory, delete branches) happens on the next worktreeCreate call.
---

1. Commit all uncommitted changes on the feature branch
2. Checkout `main`, merge the feature branch into `main` with a conventional commit message, then push
  - be sure to reference relevant Github issues in commit messages (if any)
  - update Github issues, if any
3. Call `worktreeList` to confirm the current worktree context
4. Call `worktreeDelete` with a short summary of work — this validates that:
   - The worktree has **no uncommitted changes**
   - The branch is **fully merged into `main`** (unless `--force` is set)

   To delete a worktree from a **different session** (e.g., from the parent repo session), provide the branch name:
   `worktreeDelete(branch: "feature/my-feature", reason: "PR merged, cleanup")`

   If the merge check fails:
   - If the branch was squash-merged on GitHub, pull the latest `main` first, then retry
   - If it still fails or the merge method is uncertain, ask the user for confirmation
   - If the user confirms it's safe, re-call with `--force`:
     `worktreeDelete(reason: "...", branch: "feature/my-feature", force: true)`
5. On success, explain: the worktree is **marked for cleanup** — the directory stays alive until the next `worktreeCreate` call, then cleanup completes automatically (git worktree directory and local/remote branches are removed).

**IMPORTANT: Never use `rm -rf` on a worktree directory.** This orphans the active opencode session and can cause data loss or corruption. Always use `worktreeDelete` — it validates safety first, preserves session continuity, and cleans up properly via the deferred model.

Use specified plugin tools only. Inform the user if they are unavailable. Do not use raw bash tools.
