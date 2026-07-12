---
description: Delete the current worktree session (commit + cleanup on session end)
agent: copilot
---

1. Call `worktreeList` if you need to confirm the current worktree context.
2. Call `worktreeDelete` with a short summary of work for current worktree to cleanup CURRENT worktree
3. Tell the user cleanup runs when the session ends (commit snapshot + worktree removal).

Use specified plugin tools only. Inform user if they are  unavailable. Do not use raw bash tools.
