---
description: Finish work in current worktree, commit, PR, and cleanup
---

Wrap up the current worktree session:

1. Commit all uncommitted changes with a conventional commit message
2. Push to remote
3. Create a PR merging this branch into main
4. Call worktree_delete(reason) to clean up the worktree

Follow the conventions in AGENTS.md for commit messages and PR creation.
