---
description: France en Chiffres-improve event
agent: copilot
---
## Task: improve event md file(s) in `src/content/events`

- Follow the detailed content writing guidelines in [grammar-AGENTS.md](grammar-AGENTS.md)
- replace the improvement advices (`{!xxx}`) and placeholders (`{}`) with relevant content
  - if `{une illustration, ...}, locate an illustrative image online (e.g., via wikipedia)
    - do NOT hand draw SVGs from scratch : you do not have the competence to draw professional SVG illustrations
  - if `{une carte leaflet}, create a map with relevant base map tiles (e.g., OSM} and data found online.
    - use tippy for onhover info box
    - example to reference: https://france-stats.org/monde/carte-interactive/
  - if {replace by appropriate statistical chart} or {add appropriate statistical chart: ...}
    - should find reliable, relevant statistics online, then draw statistical diagram with D3.js, mermaid, or other appropriate lib
- correct grammar while preserving writing style to the maximum

