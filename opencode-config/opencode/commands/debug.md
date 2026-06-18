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
3. fix problematic code/AGENTS.md/doc, etc. for ALL occurences
  - if fix required in external directory outside `.`, ask user for direction
