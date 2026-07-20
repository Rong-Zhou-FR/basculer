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
