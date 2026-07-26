---
description: reflect on session and learn
agent: copilot
---

Reflecting on the current session $1, are there any lessons (testing procedure, debugging strategy, project organisation, documentation) that is worth noting for future reference:

- for current/another project ?
- for all future coding sessions ?

Explain to user in two markdown tables.

**Important — lesson numbers (PJ1, G1, etc.) are ephemeral conversation identifiers only.**
Do NOT write them into AGENTS.md or any persistent file. They exist solely to reference
specific lessons during the validation discussion. When writing lessons into AGENTS.md,
use plain prose — no numbering.

Lessons for current project:

|lesson number|experience|lesson|
|:------------|:---------|:-----|
|(PJ1,PJ2,PJ3...)   |(what happened in this session)|(what we leanrt for the project)|

Lessons for all future coding sessions:

|lesson number|experience|lesson|
|:------------|:---------|:-----|
|(G1,G2,G3...)   |(what happened in this session)|(what we leanrt for for all future coding sessions)|

**Step 1 — Use `question` tool to invite user validation and recategorization.** Present the tables, then use
the `question` tool to ask the user for two lists of validated lesson numbers:

| field | prompt | widget |
|-------|--------|--------|
| `listA` | *Which lessons belong in the project AGENTS.md? (PJ1, PJ2, ...)* | multi-select or free-text |
| `listB` | *Which lessons belong in ~/.config/opencode/AGENTS.md? (G1, G2, ...)* | multi-select or free-text |

The user recategorizes validated lessons by putting each lesson number into the list where it belongs
  - e.g., if user puts `PJ3` into `listB`, that means this lesson should be global, not project-scoped as you suggested.
If user does not mention a lesson number in any list, it is rejected (implicit rejection).

**Step 2 — Propose diffs and use `question` tool for sign-off.** Based on the user's
approved lists, write the exact text you intend to add to each file (no lesson-number
tags). Present the proposed diffs in a code block and use the `question` tool to ask:
"Are these diffs correct? May I edit the files?" Do NOT edit any persistent file until the
user approves explicitly.

NOTE: When writing to AGENTS.md:
  - bad :
    - append lessons directly at bottom of file
    - include lesson numbers like `PJ2`
  - good : incorporate insights into existing workflow/dev convention sections and enhancing them


