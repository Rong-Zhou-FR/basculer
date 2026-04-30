---
description: Turn your "./dev/plan/0-idea.md" into a concrete plan
agent: build
---

## Tasks

1. Use "read" tool to read "./dev/plan/0-idea.md". 

2. Use "write" tool to propose in "./dev/plans/0-init-plan.md":

-  project architecture
-  tech stack

Each should be illustrated in a hierarchical list.

If there are multiple viable options, explore all of them, compare their advantages and drawbacks and determine which one is the best. Document your comparison in a markdown table.

You should consider:

  - dependencies
    - 100 % FOSS is best for guaranteed long-term stability and security 
    - lightweight, well documented, popular packages are most reliable
  - scalability
    - if the project grows exponentially, and there are regularlly new contributors joining:
      - would the repo architecture be self-explanatory ?
      - would them be able to understand the functionning of each module and general code structure rapidly ?
    - is the repo structure appropriate for a production-grade, high resource-efficiency implementation ?
  - ease for agentic AI
    - would the structure be clear to agentic AIs reading/editing files ? debugging ?
  - modularity
    - are different modules cleanly separated, each with a defined input/output, so editing one module wouldn't cause problems elsewhere ?

## Requirements

- You must write coincisely and straight to the point

