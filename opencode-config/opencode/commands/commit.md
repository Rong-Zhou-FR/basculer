---
description: make commits with conventional message
agent: copilot
---

Follow AGENTS.md conventions.

- Use git tools to explore ALL uncommitted changes
  - including pre-existing changes predating this session
- Group them into 1+ functional units
- Outline a commit proposal (1 commit per functional unit) with markdown table:

|commit #|changes made|suggested commit message|
|------|------------|------------------------|
|1,2,3...|xxx file: line xx-xx, did xxx...|feat:xxx, chore:xxx,refactor:xxx fix:xxx...|

- ASK for user sign-off, then make the commits
- push to remote
