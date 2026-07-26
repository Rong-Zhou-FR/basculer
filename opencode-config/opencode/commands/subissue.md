---
description: approve plan and instruct agent to work through large diff systematically via Github subissues
agent: copilot
---

Approved. Now:

- Break your plan down by logical group 
  - e.g., by feature, by file path
  - create one Github subissue per logical group to document detailed implementation plan
    - subissue goal, diff (what file), acceptance criteria
- implement systematically subissue by subissue. For each subissue:
  - run relevant tests to validate changes (not full-suite, just relevant ones for efficiency)
  - make one commit after test validation with conventional git commit message
- run one final, more comprehensive test to validate that the parent issue is fully resolved.
- PR into main and report back to user
