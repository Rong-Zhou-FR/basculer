# Agent Deduplication Plan

## Decision
Approved by architect consultation and filed as GitHub issue #3.

## Key Findings (Corrected)
- `opencode/AGENTS.md` exists but is empty (0 lines) — architecture diagram says it should be the shared base prompt
- ~284 lines of duplication across agent files can be removed
- AGENTS.md content IS included for all LLM calls (primary agents AND subagents) per opencode docs. No comment markers or workarounds needed.
- The `instructions` field in opencode.jsonc is optional — AGENTS.md is auto-loaded

## Sections to Centralize
1. Tone & Style (core: concise, direct, GFM)
2. Tool Usage (Serena tools, workdir rule, ctx docs workflow)
3. Delegation Workflow
4. Consulting Expert (Use Sparingly) protocol
5. Memory & State base pattern

## Sections to Keep Per-Agent
- YAML frontmatter + permissions
- Focus Areas / role-specific workflows
- Division of Responsibility
- Role-specific guidelines, limitations, output formats
- Tool Selection Guidance (where unique)
- Security & Professional Judgement (role-specific)

## Also Affected (commands/)
- `commands/approve.md` — ~20 lines of generic dev conventions (monolith rule, Python3, branching) → move to AGENTS.md
- `commands/debug.md` — "consult @architect for structural changes" shared convention → move to AGENTS.md
- `commands/issue.md` — "conform to repo standards" generic criteria → move to AGENTS.md
- `fec-events*.md` — legitimately domain-specific, NOT affected

## Results
- **16 files modified**: 1 AGENTS.md created + 13 agents trimmed + 3 commands cleaned
- **~404 lines removed**, **130 lines added** (AGENTS.md), **net -274 lines**
- **Branch**: `feat/dedup-agent-instructions`
- **PR**: https://github.com/Rong-Zhou-FR/basculer/pull/4
- **Issue #3**: Closed with completion comment

## Batch 2 (commit 421b9ee)
- Symbol Editing + Command Execution promoted to AGENTS.md Tool Usage
- "Refuse Unreasonable Requests" centralized to AGENTS.md
- "ALWAYS contribute methodically" pruned in copilot.md + auditor.md (keep only unique details)
- "Manage dependencies wisely" removed from copilot.md (already in AGENTS.md)
- copilot.md: 204→110 lines, auditor.md: 178→94 lines
- Total duplication removed across both batches: ~468 lines from agents, +127 lines AGENTS.md = net -341

## Implementation Status
- [x] Analysis complete (architect consultation, docs verified)
- [x] GitHub issue filed: https://github.com/Rong-Zhou-FR/basculer/issues/3
- [ ] Implementation (not started — user asked to NOT edit files yet)
