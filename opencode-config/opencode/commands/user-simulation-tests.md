---
description: run user-simulation tests
agent: copilot
---

Run user-simulation testing on $1.

For full regression coverage, prefer CI (`gh workflow run ci.yml -f scope=e2e`
if available). Only run locally if CI is unavailable or for live debugging.

If bugs found, fix them, then rerun testing. 

Follow all conventions in AGENTS.md, including the testing report format.


