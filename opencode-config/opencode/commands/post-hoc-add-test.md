---
description: Add tests post-hoc to existing code (spec-first protocol)
agent: tester
---

Write tests for existing code that has none. Use a spec-first protocol to
prevent the default LLM failure mode of modifying assertions to match buggy code.

---

## Phase 1: Spec — Document Intent

### 1. Derive expected behavior from external sources

Read the interface, then reconstruct intent from **external** sources — NOT
from reading the implementation body (that makes the spec circular):

- Docstrings, module docs, project README
- Issue tracker (does this code address a known issue?)
- PR descriptions / commit messages that introduced the code
- Inline comments describing purpose
- Other test files that exercise the same code

### 2. Write `spec/` and get approval

Create `spec/<module>.md` in the project root with:

- Inputs, outputs, edge cases per function
- Error conditions and handling
- Behavioral contracts (preconditions, postconditions, invariants)

**Proportionality**: Scale to code complexity. A 20-line pure function needs
a few paragraphs, not a 10-page document. If the behavior is unambiguous
(e.g. `def add(a, b): return a + b`), a single sentence suffices — move on.
Overengineering the spec discourages writing it.

**Ask for user approval** before proceeding to Phase 2.

---

## Phase 2: Test — Write and Run

### 3. Write tests against the spec

The spec is the ground truth — not the implementation. If they disagree, the
implementation is suspect.

Test at the appropriate layer per AGENTS.md conventions.

### 4. Run. If fail, rerun.

If tests fail, rerun. If they pass the second
time, note as flaky and proceed.

---

## Phase 3: Reconcile — User Decides Truth

### 5. Three-way evidence comparison

If tests consistently fail after rerun, **do not modify assertions or code**. Instead report a three way comparison to user:

| Point | Source | Meaning |
|-------|--------|---------|
| **Spec** | spec/ (approved in Phase 1) | What *should* happen |
| **Test** | Your test's assertion | What the test *expects* |
| **Code** | Actual output from execution | What the code *produces* |

### 6. User decides

Present the evidence and your interpretation, then **let the user decide** what
is right and what to fix. Do not unilaterally modify code, spec, or test
assertions after the three-way comparison.

### 7. Loop

After the user's decision and any fixes, rerun tests from step 4. If still
failing after 2 iterations, call @reviewer for an independent assessment.
