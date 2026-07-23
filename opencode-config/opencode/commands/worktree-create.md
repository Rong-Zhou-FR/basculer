---
description: Create an isolated git worktree with OpenCode in a new terminal. A new terminal will spawn — go there to work.
agent: gitmaster
---

Call the `worktreeCreate` tool NOW to create isolated git worktree(s). 

- Branch: Use descriptive, conventional branch name illustrating purpose(s) for the worktrees: "$ARGUMENTS".
- Base branch: if not specified, default to HEAD.

After calling the tool, briefly report: branch name(s), worktree path(s), and that a new terminal opened.

Do NOT run raw `git worktree` bash — use `worktreeCreate` only. Brief user if `worktreeCreate` is not available.
