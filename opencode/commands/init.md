---
description: Initialize project from plan
agent: copilot
---

1. use "Read" tool on `./dev/plans/0-init-plan.md` to understand project requirements
2. Based on requirements, create:
   - Project structure (directories, config files)
   - Initial source files
   - `./AGENTS.md` (root)
   - `./module/AGENTS.md` for each submodule (from template)
3. Use `ctx_batch_execute` to run multiple setup commands
4. If creating a git repo, also run `git init`
