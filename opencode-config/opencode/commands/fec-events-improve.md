---
description: France en Chiffres-improve event
agent: copilot
---
## Task: improve event md file(s) in `src/content/events`

## requirements

- correct grammar while preserving writing style to the maximum
  - for tense, use past tenses when speaking of events in the past
    - avoid using the present tense for past events, even when telling stories, as this is confusing
    - in French, use passé simple, imparfaits, passé composé, etc. as appropriate to describe historical events
- use inclusive language
  - in French, use point median for gender-depdendent nouns and adjectives when appropriate: chercheur·e, agriculteur·euse, heureux·euse, e·ils (au lieu de ils)
    - do not do this when the subjects are actually all masculin (e.g., rois, évêques in middle age, unless you are sure that there was a female)
  - maintain religious neutrality with AEC/EC (avant ère commune/ère commune)
- add references for facts where they are missing (marked with `{x}`)
  - procedure
    1. search for reliable references
      - prioritise academic journals and reliable scientific sites
      - avoid unverified, low quality content
      - must not invent fictive sources
        - use web search 
        - if no source found to support claim in passage, signal to user
    2. create sources in src/content/sources with valid CSL-JSON schema
    3. cite the sources inline in the event md file with `[source:{source-id}]`
    4. in case of factual error in the passage (year, names, etc.), rewrite the concerned sections according to the sources
- replace `{xxx}` placeholders with corresponding content
- implement the improvement advices (`{!xxx}`) then remove the advices 

