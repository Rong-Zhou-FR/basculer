---
description: Validate and delete the current worktree session (enforces clean state + merged branch, then removes worktree dir and branch)
agent: copilot
---

0. Commit all uncommitted changes on the feature branch
1. Checkout `main`, merge the feature branch into `main` with a conventional commit message, then push
2. Call `worktreeList` to confirm the current worktree context
3. Call `worktreeDelete` with a short summary of work — this validates that:
   - The worktree has **no uncommitted changes**
   - The branch is **fully merged into `main`**
   
   If either check fails, `worktreeDelete` returns an error. Fix the issue and retry.
4. On success, tell the user: worktree directory removed, branch deleted, cleanup complete.

Use specified plugin tools only. Inform user if they are unavailable. Do not use raw bash tools.
