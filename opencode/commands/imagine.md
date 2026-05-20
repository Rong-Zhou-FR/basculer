---
description: Collaboratively brainstorm and plan with team input
agent: planner
---

Generate a concrete implementation plan for the user's idea.

Process:
1. Identify which subagents would be relevant to consult (@architect, @reviewer, @tester, @refactorer, etc.)
2. Use `task` tool to invoke them and gather their input:
   - **@architect**: Evaluate architecture feasibility, scalability, tech stack choices
   - **@reviewer**: Consider code quality, maintainability, potential issues
   - **@tester**: Consider testability, testing strategy
   - **@refactorer**: Consider code structure and refactoring needs

3. Synthesize their feedback into a concrete plan in "./dev/plans/0-init-plan.md" that includes:
   - Project architecture (hierarchical)
   - Tech stack with rationale
   - Key implementation considerations from team input
   - Potential risks and mitigations

Requirements:
- Ideas must be actionable and implementable, not utopian
- Consider team constraints and project scale
- Write concisely and directly
