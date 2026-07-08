---
description: Diagnose and fix errors
agent: copilot
---

Debug $1

1. Identify root cause of undesired behavior
  - implementation problem ?
    - if the error message is too generic for effective debugging, first add more detailed error handling, then try to reproduce the error urself 
  - AGENTS.md requirements not meeting user expectation ?
    - in this case, STOP, brief user before moving onto 2.
2. perform a systematic review if the same problem exists elsewhere in the codebase
  - create github issues on relevant repos to document all occurences
3. fix problematic code/AGENTS.md/doc, etc. for ALL occurences
  - if fix required in external directory outside `.`, ask user for direction
4. run tests relevant to the code changes (not the full suite unless there is specific reason to suspect wide-ranging breakage)
5. user simulation testing
  - use the program as an end user would and catch unexpected behaviours
6. commit, push, create PR, and merge to main

