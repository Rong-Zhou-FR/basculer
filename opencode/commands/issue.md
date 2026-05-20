---
description: Give copilot context about a GitHub issue
agent: copilot
---

Moving on. We are working on issue $1.

## TASKs

- Fetch context via @githubber
- update github issue and brief user
  - if somebody already proposed a solution, evaluate critically. You either
    - approve 
    - propose an enhanced version
    - reject, give reason, and make counter proposal
  - else, simply propose your solution
    - your solution must
      - conform to repo standards specified in workspace, repo, and module AGENTS.md, if those exist
      - be secure, simple, and address root issue
  - in all cases, consult relevant subagents, if applicable (e.g., @architect for architectural decisions
- Do NOT edit any files yet
