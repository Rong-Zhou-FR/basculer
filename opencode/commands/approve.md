---
description: approve AI proposed action
agent: copilot
---

Approved. Now: 

- review system prompt to ensure conformity
- update todo list
- before you start work, confirm that if the files you plan to modify are part of a git repo
  - if so, verify branch name
     - if it does not correspond to your planned tasks, commit changes if any and create a new branch to work on
     - you should NOT work directly on `main`, as there are often multiple developers on A-core
- implement proposal
  - create automated tests, run them, ensure all passes
  - then do a user‑simulation testing (test the functionality as a user would)
- commit and push to github
  - if `./` is not git repo, check sub-folders. some workspaces have each module initialised as an individual git repo.
  - if you created a new branch to work on, merge it in to the main branch
  - you should mention the relevant github issue(s) (#n) in your commit message, if any.
- update AGENTS.md, README.md, readthedocs files, and relevant github issue(s) to reflect latest progress
  - if a github issue has been completed, close with closing comment

- **IMPORTANT**
  - monolith files > 500 lines are not readable for humans. Forbidden.
    - if you spot/create any monolith files, split by functional units into smaller files
  - observe Python3 conventions
    - variable names and comments should be in plain English, even if userspace is multilingual/non-English
