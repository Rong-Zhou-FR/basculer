---
description: Diagnose and fix errors
agent: copilot
---

Debug $1

1. Identify root cause of undesired behavior
   - Trace the causal chain: for each apparent cause, drill down with "why does this happen?"
     until you reach the fundamental mechanism. The root cause is the one that, if corrected,
     eliminates the symptom entirely — not the cheapest surface patch.
   - Avoid LLM tendency to fix symptoms: if you find yourself patching a single call site
     while the same underlying pattern exists elsewhere, you have not found the root cause.
   - implementation problem ?
     - if the error message is too generic for effective debugging, first add more detailed
       error handling, then try to reproduce the error yourself
   - AGENTS.md requirements not meeting user expectation ?
     - in this case, STOP, brief user before moving onto 2.

2. Perform a systematic review if the same root cause exists elsewhere in the codebase
   - Search for the same underlying pattern, not just the same error string
   - Create github issues on relevant repos to document all occurrences

3. BEFORE writing any fix code, brief the user with:
   - The root cause (what mechanism produces the bug)
   - Which files would be changed and how
   - Whether the same root cause manifests elsewhere in the codebase
   Await user go-ahead before proceeding to step 4.

4. Fix problematic code/AGENTS.md/doc, etc. for ALL occurrences of the root cause

5. Run tests relevant to the code changes (not the full suite unless there is specific reason
   to suspect wide-ranging breakage)

6. User simulation testing (follow AGENTS.md conventions)

7. Commit, push, create PR, and merge to main
