---
description: run user-simulation tests
agent: copilot
---

## task: user-simulation testing

- Test $1 as if you are the end-user
  - if credentials needed, look for `.dev` file
    - if not found, ask user for test credentials 
  - if webGUI, use playwright browser
    - if you do not know how to access the browser, STOP and ask for user direction
    - run with `head:false` (headless mode) by default for efficiency. Switch to `head:true` if needed
- Try all available commands and all options
- Fix failures
