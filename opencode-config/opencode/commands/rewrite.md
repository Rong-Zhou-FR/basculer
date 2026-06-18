---
description: Give copilot context about a GitHub issue
agent: copilot
---

We are working on rewriting $1, implemented at $2 as $3 implemented in $4.
You should NOW:

1. Consult ./AGENTS.md to understand global rewrite strategy and progress
2. Consult relevant module AGENTS.md to understand scope of concerned module
3. Ask @explore for a quick view on both the old implementation and the state of the new one
4. propose concrete, delivrable, testable github issues to advance the rewrite, satisfying the following criteria:

- enhance modularity
- increase performance
- lean down code: when existing libraries already exist, we should use them instead of reinventing the wheel
  - and reinventing wheel we did in the old implementation

- if anything is not clear, consult relevant AGENTS.md. If it is still not clear, you do not hesitate before asking user


