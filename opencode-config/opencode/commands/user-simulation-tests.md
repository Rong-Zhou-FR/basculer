---
description: run user-simulation tests
agent: copilot
---

## task: user-simulation testing

- Test project as if you are an end-user
  - if credentials needed, look for `.dev` file
    - if not found, ask user for test credentials 
  - if webGUI, use playwright browser
    - if you do not know how to access the browser, STOP and ask for user direction
    - run with `head:false` (headless mode) by default for efficiency. Switch to `head:true` if needed
- Try all relevant commands and options in the specified scope: $1
  - note any changes made to the userDB, and revert them when you are done
- Fix failures

