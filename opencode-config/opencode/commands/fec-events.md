---
description: France en Chiffres-create or complete event
agent: copilot
---
## Task: generate or complete event md file(s) in `src/content/events`

## requirements

- correct schema
- treat existing events files as writing style examples
- do
  - use inclusive language
    - in French, use point median for gender-depdendent nouns and adjectives: chercheur·e, agriculteur·euse, heureux·euse, e·ils (au lieu de ils)
    - maintain religious neutrality with AEC/EC (avant ère commune/ère commune)
  - write an engaging intro
    - tell a story
      - ideas
        - one particular episode of a real/fictive character in the historical event/era
          - prioritise common people for relatablity: « people relate more to a farmer's child than a king »
    - ask user a relatable question 
  - be representative: « speak of the glorious, but also the ignored »
    - mention notable people/events and their impact on history of France
    - but also dive into the society and life of different social groups
  - reference facts
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
- do not
  - mechanically copy the text structure in examples
  - simply list generic, boring historical facts

## topic: $1
