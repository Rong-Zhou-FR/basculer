---
description: Spawn isolated development environment via git worktree
agent: gitmaster
---

Call worktree_create(branch="$1", baseBranch?) to spawn an isolated git worktree with a fresh OpenCode session. If no branch name is provided, derive one from the context of what the user wants to work on.
