---
description: propose one or more GitHub issues based on user input, ask for approval, then create them
agent: copilot
---

Create GitHub issue(s): $1

## Workflow

### 1. Propose issue(s) to create and request user approval

For each issue you propose, prepare:

| Field | How to determine |
|-------|-----------------|
| **Title** | Short, descriptive, conventional (e.g. "Add dark mode support") |
| **Body** | Structured with context, acceptance criteria, and any technical notes. Write to a temp file for `--body-file` (never inline). |
| **Labels** | Suggest labels that should exist on the repo (e.g. `enhancement`, `bug`, `docs`). List the ones that need creating. |
| **Repo** | Default: the current repo (derive from `git remote get-url origin`). If the user wants a different repo, ask which one. |

**Use one `question` call per issue to request user approval

**Wait for explicit approval before creating anything.**

### 1.5 Phase large issues with sub-issues

After the user approves the proposed issue(s), assess whether any issue represents a large change that would benefit from phasing. A large change typically involves:

- Multiple independent or sequential steps across different subsystems
- A change that would produce an unwieldy PR (>500 lines changed)
- Work that could be split into independently reviewable chunks
- Work spanning multiple days or agents

For each large issue, **propose a sub-issue breakdown** before creating anything:

| Field | How to determine |
|-------|-----------------|
| **Parent issue** | The approved high-level issue (this is the original proposal) |
| **Sub-issues** | Logical phases: each should be independently implementable and testable. Name them clearly (e.g. "Phase 1: Backend API", "Phase 2: Frontend UI") |
| **Ordering** | Dependencies between sub-issues (which must be done first) |

**Present the breakdown for approval** before creating anything. Use one `question` call.

If the user declines sub-issues (change is small enough), skip to step 2.

### 1.6 Create parent issue first, then sub-issues

Once the breakdown is approved:

1. Create the **parent** issue first (using the normal `gh issue create` flow).
2. For each sub-issue, create it with its own body (detailing that phase's goal, diff scope, and acceptance criteria).
3. **Link each sub-issue to its parent** via GraphQL:
   ```bash
   # Get node IDs for parent and all sub-issues
   gh api graphql -f query='
   query {
     repository(owner: "'"$ORG"'", name: "'"$REPO"'") {
       parent: issue(number: PARENT_NUM) { id }
       child1: issue(number: CHILD1_NUM) { id }
       child2: issue(number: CHILD2_NUM) { id }
     }
   }' --jq '.data.repository'

   # Link each child to parent
   gh api graphql -f query='
   mutation {
     addSubIssue(input: {
       issueId: "PARENT_NODE_ID",
       subIssueId: "CHILD_NODE_ID"
     }) { subIssue { id } }
   }'
   ```
4. Report the full hierarchy (parent + all sub-issues with URLs and dependency order).

### 2. Ensure labels exist

For each proposed label, check if it exists on the target repo:

```bash
gh label list --repo "$ORG/$REPO" --json name --jq '.[].name'
```

Create any missing labels with:

```bash
gh label create "$LABEL" \
  --repo "$ORG/$REPO" \
  --description "$DESC" \
  --color "$COLOR"
```

(Pick a reasonable color from the GitHub default palette unless the user specifies otherwise.)

### 3. Create issue(s)

Once the user has approved the final set:

```bash
# Write body to temp file (always use --body-file, never inline)
cat > /tmp/issue-body.md << 'BODY'
(issue body content)
BODY

gh issue create \
  --repo "$ORG/$REPO" \
  --title "$TITLE" \
  --body-file /tmp/issue-body.md \
  --label "$LABEL1" \
  --label "$LABEL2"
```

If creating multiple issues, create them one at a time and report each URL as it's created.

### 4. Report results

After all issues are created, summarise:

- List each issue with its URL
- Note any labels that were created
- Ask if the user wants to do anything else with these issues (e.g. add to a milestone, link as sub-issues)
