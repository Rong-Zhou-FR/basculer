---
description: Delete the current worktree session (commit + cleanup on session end)
agent: copilot
---

0. If there are any uncommitted changes, commit them
1. merge branch into main with conventional message
2. Call `worktreeList` if you need to confirm the current worktree context.
3. Call `worktreeDelete` with a short summary of work for current worktree to cleanup CURRENT worktree
4. Tell the user cleanup runs when the session ends (commit snapshot + worktree removal).

Use specified plugin tools only. Inform user if they are  unavailable. Do not use raw bash tools.
