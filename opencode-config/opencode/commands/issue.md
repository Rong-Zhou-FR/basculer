---
description: Give copilot context about a GitHub issue
agent: copilot
---

Moving on. We are working on issue $1.

## TASKs

- fetch context via gh CLI
- update github issue and brief user
  - if somebody already proposed a solution, evaluate critically. You either
    - approve 
    - propose an enhanced version
    - reject, give reason, and make counter proposal
  - else, simply propose your solution
    - your solution must address root issue
  - in all cases, consult relevant subagents if applicable
- Do NOT edit any files yet
