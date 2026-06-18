---
description: approve AI proposed action
agent: copilot
---

Approved. Now: 

- review your system prompt to ensure conformity
- update todo list
- before you start work, confirm that if the files you plan to modify are part of a git repo
  - if so, you must work on an appropriate branch
     - if no existing branch name correspond to what you are doing, create new one 
     - if repo "dirty" with unrelated changes
       - if those look like partial edits, stash them 
       - if those look like completed functional units/bug fixes, commit them and merge into main
     - you should NOT work directly on `main` to avoid conflict with collaborators
- implement proposal
  - create automated tests, run them, ensure all passes
  - then do a user‑simulation testing (test the functionality as a user would)
- commit and push to github
  - if `./` is not git repo, check sub-folders. some workspaces have each module initialised as an individual git repo.
  - if you created a new branch to work on, merge it into the main branch via a Github PR.
  - you should mention the relevant github issue(s) (#n) in your commit message, if any.
  - switch back to main git branch and retore stashed changes, if any
- update AGENTS.md, README.md, readthedocs files, and relevant github issue(s) to reflect latest progress
  - if an existing github issue has been completed, close with closing comment
  - if no relevant github issue exists, create one to document problems identified, solution implemented, and close

- **IMPORTANT**
  - monolith files > 500 lines are not readable for humans. Forbidden.
    - if you spot/create any monolith files, split by functional units into smaller files
  - observe Python3 conventions
    - variable names and comments should be in plain English, even if userspace is multilingual/non-English
