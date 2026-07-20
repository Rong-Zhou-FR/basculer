# GitHub CLI (`gh`) Usage Guide

Practical patterns for common `gh` operations. The critical parts (GraphQL mutations, node IDs, file-based body rules) are inlined in `opencode/AGENTS.md` so the LLM always sees them. This file is the full reference for humans and edge cases.

---

## Basic Issue Operations

### Fetching Issue Details

```bash
# Full view with comments
gh issue view 243 --repo owner/repo --comments

# Structured JSON (select specific fields)
gh issue view 243 --repo owner/repo --json title,body,comments,labels,assignees,state

# Getting JSON field names — if you guess wrong, the error tells you available fields:
#   "Unknown JSON field: 'parent'"
#   Available fields: assignees, author, body, comments, labels, ...
#
# Re-run with the corrected field list.
```

### Creating Issues

```bash
gh issue create --repo owner/repo \
  --title "My issue title" \
  --label "enhancement,bug" \
  --body-file /tmp/issue-body.md
```

### Editing Issues

```bash
# Add labels, assignees, milestone
gh issue edit 244 --repo owner/repo \
  --add-label "enhancement,cli,email" \
  --add-assignee "@me"

# Update body from file
gh issue edit 134 --body-file /tmp/issue-body.md
```

### Commenting on Issues

```bash
gh issue comment 243 --repo owner/repo --body-file /tmp/comment-body.md
```

### Labels

```bash
# Labels must exist before you can assign them
gh label list --repo owner/repo --limit 50

# Create a new label (color is hex without #)
gh label create cli --repo owner/repo \
  --description "CLI command changes" \
  --color "5319e7"
```

---

## Advanced: GraphQL for Relationships

`gh issue edit` does not support parent/child or blocked-by relationships. Use `gh api graphql` for these.

### Getting Node IDs

Every GitHub node has a global ID required for GraphQL mutations:

```bash
gh api graphql -f query='
query {
  repository(owner: "owner", name: "repo") {
    issue243: issue(number: 243) { id }
    issue244: issue(number: 244) { id }
  }
}' --jq '.data.repository'
```

Returns e.g. `{"issue243": {"id": "I_kwDO..."}, "issue244": {"id": "I_kwDO..."}}`.

### Sub-issues (Parent/Child)

```bash
gh api graphql -f query='
mutation {
  addSubIssue(input: {
    issueId: "PARENT_NODE_ID",
    subIssueId: "CHILD_NODE_ID"
  }) {
    subIssue { id }
  }
}'
```

- `issueId` = the **parent** issue's node ID
- `subIssueId` = the **child** issue's node ID
- `replaceParent: true` to move a sub-issue that already has a parent

### Blocked-by / Blocks Relationships

```bash
gh api graphql -f query='
mutation {
  addBlockedBy(input: {
    issueId: "BLOCKED_ISSUE_NODE_ID",
    blockingIssueId: "BLOCKING_ISSUE_NODE_ID"
  }) { clientMutationId }
}'
```

- `issueId` = the issue that **is blocked** (depends on the other)
- `blockingIssueId` = the issue that **blocks** it (prerequisite)

### Verifying Relationships via GraphQL

```bash
gh api graphql -f query='
{
  repository(owner: "owner", name: "repo") {
    master: issue(number: 243) {
      subIssues(first: 10) {
        nodes { number title }
      }
    }
    child: issue(number: 248) {
      blockedBy(first: 5) {
        nodes { ... on Issue { number title } }
      }
    }
  }
}' --jq '.data.repository'
```

### Inspecting the GraphQL Schema

When you don't know the mutation or field names, query `__type`:

```bash
gh api graphql -f query='
{ __type(name: "AddSubIssueInput") {
    inputFields {
      name
      type { name kind }
      description
    }
  }
}'

# Or search for types by pattern
gh api graphql -f query='
{ __schema {
    mutationTypes: types {
      name
      fields { name }
    }
  }
}' --jq '[.data.__schema.mutationTypes[] | select(.name | test("Issue|Block")) | .name]'
```

---

## File-Based Body Patterns

**Always use a temp file for issue/PR bodies.** Inline strings with markdown, backticks, or special characters (`(`, `)`, `!`) are prone to shell escaping errors.

### Pattern A: Write tool → `gh` (most reliable)
```
write(filePath="/tmp/issue-body.md", content="## Title\n\nBody with `backticks`.")
→ then →
gh issue create --title "..." --body-file /tmp/issue-body.md
```

No shell layer touches the content — write tool places it directly on disk.

### Pattern B: Heredoc with single-quoted delimiter (when write isn't available)
```bash
cat > /tmp/issue-body.md << 'ISSUE'
## Problem
Description with `backticks`, (parentheses), and ! marks.
ISSUE
gh issue create --title "..." --body-file /tmp/issue-body.md
```

Use `<< 'EOF'` (single-quoted delimiter) — prevents bash variable expansion and most escaping issues. However, **backticks inside markdown code fences can still leak** through in nested contexts (e.g. `python3 -c` inside the same bash invocation).

### When NOT to use heredocs
- Content contains backticks inside code fences AND the heredoc is nested inside another shell construct (`python3 -c`, `bash -c`)
- Content contains `$` signs in unexpected places
- Content has complex nested markdown with colons in `prefix:` notation

→ Fall back to Pattern A in these cases.

---

## Reference: Common Patterns

```bash
# List all labels
gh label list --repo owner/repo --limit 50

# List issue comments
gh issue view 243 --repo owner/repo --comments

# Check closed PRs referencing an issue
gh issue view 243 --repo owner/repo --json closedByPullRequestsReferences

# Parallel execution — independent gh calls in a single message
# (no sequential dependencies between them)
```

---

## Pitfalls

1. **Labels must exist** before you can `--add-label`. Create them first via `gh label create`.
2. **`gh issue view` JSON fields** are validated client-side. Error message lists available fields — trust it, don't guess.
3. **Node IDs are repo-scoped.** The same issue number in different repos has different node IDs. Get fresh IDs for each repo.
4. **GraphQL mutation names** are not always what you expect. Always verify via `__type` introspection before writing complex mutations.
5. **Rate limits:** `gh api graphql` counts toward GitHub API rate limits. Batch multiple mutations in a single query when possible.
