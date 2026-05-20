---
description: Diagnose and fix errors
agent: copilot
---

In addition, debug $1

1. Identify root cause of undesired behavior
  - implementation problem ?
    - if the error message is too generic for effective debugging, first add more detailed error handling, then try to reproduce the error urself 
  - AGENTS.md requirements not meeting user expectation ?
    - in this case, STOP, brief user before moving onto 2.
2. perform a systematic review if the same problem exists elsewhere in the codebase
  - create github issues on relevant repos to document all occurences
3. review your agent prompt and relevant AGENTS.md files
4. fix problematic code/AGENTS.md/doc, etc. for ALL occurences
  - if fix required in external directory outside `.`, ask user for direction
  - if structural changes needed, ask @architect to plan, update Github issue with @architect's proposal, then ask for user approval
5. when finished, commit, push and close issues
