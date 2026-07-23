---
description: End-to-end GitHub issue resolution workflow
agent: copilot
---

We are working on issue $1.

## Workflow

### Phase 1: Investigate & Propose

1. **Fetch context** via `gh` CLI:
   - Issue details, comments, existing proposals

2. **Investigate thoroughly**:
   - Read relevant source files
   - Reproduce the issue if applicable
   - Evaluate any existing proposals — either approve, enhance with reasoning, or reject with counter-proposal

3. **Present findings** to the user:
   - Root cause analysis
   - Proposed solution with rationale
   - Implementation plan (files to touch, approach)
   - Any risks or tradeoffs

4. **Ask for user signoff** — wait for explicit approval before proceeding to Phase 2.

---

### Phase 2: Implement (after user signoff)

5. **Verify branch safety**:
   - Run `git branch --show-current`
   - If on `main` or not on a dedicated feature branch → use `worktreeNew` tool to create an isolated worktree
   - set workdirectory to the isolated worktree
   - All subsequent file edits and git operations must happen inside the worktree directory and NOT on repo

6. **Implement the solution**:
   - Follow AGENTS.md coding conventions (error discipline, readability, test requirements)

8. **Report results** with summary of changes:
   - What was changed and why
   - Test results
   - Any uncovered issues or deviations from the plan
   - Propose one or multiple commits for your work with conventional commit messages:
    - Group into logical units
    - Mention `#N` in commit messages

9. **Ask for user validation** — wait for explicit approval before proceeding to Phase 3.

---

### Phase 3: Deliver (after user validation)

10. **Commit changes** 

11. **Push branch** to remote.

12. **Create a PR** with `--body-file` (write body to temp file):
    - Title: descriptive, matches commit scope
    - Body: summary of changes, test results, any notes for reviewer
    - Include `Closes #N` in the body so the issue auto-closes on merge

13. **Run `worktreeDelete <branch>`** — marks the worktree for deferred cleanup (directory stays until next `worktreeCreate`, hence safe).

14. **Report PR URL** to the user and ask them to review on GitHub.

---

Follow all conventions in AGENTS.md.
