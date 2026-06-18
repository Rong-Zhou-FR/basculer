# No Pytest for Non-Code Text Files

**Decision**: Do NOT write pytest tests for markdown, config, or other non-code text files (AGENTS.md, .jsonc, .md agent definitions, etc.).

**Rationale**:
- These files are documentation/config, not logic — string-matching tests are brittle and high-maintenance
- Any rephrase breaks the test, creating friction for legitimate copy edits
- The repo is a dotfiles/config collection, not a product with runtime behavior
- Code review catches structural issues in these files faster than fragile assertions
- Better alternatives: grep one-liners during review, or nothing

**Exception**: Actual code files (.py, .ts, .js, .bash) with real logic still get proper tests.
