---
description: initialise git and push to Github
agent: copilot
---

Great job.

## Next steps

- initialise project as git repo
- push to github as public repo under AGPL 3.0 licence

## instructions on gh usage: Init Git + Push to GitHub (Public, with License)

### Prerequisites

- gh CLI installed and authenticated (`gh auth status` to check)
- GitHub account with write access

### One-shot script

```bash
# From your project root:

# 1. Create .gitignore (skip if already exists, adapt actual file content to project needs)
cat > .gitignore << 'EOF'
node_modules/
dist/
.env
.DS_Store
*.local
EOF

# 2. Init repo and commit
git init
git branch -m main
git add -A
git commit -m "feat: initial scaffold"

# 3. Create repo on GitHub (public with AGPL-3.0 license)
# This creates the remote + pushes a LICENSE file
gh repo create <repo-name> \
  --public \
  --license AGPL-3.0 \
  --description "Short description of the project"

# 4. Add remote and push
git remote add origin https://github.com/<org>/<repo-name>.git

# 5. If remote already has LICENSE/README (from --license flag), merge it
git fetch origin main
git merge origin/main --allow-unrelated-histories --no-edit
# Resolve any conflicts if needed, then:

git push -u origin main
```

### License options for `--license`

| License       | Flag         |
|---------------|--------------|
| AGPL 3.0      | `AGPL-3.0`   |
| MIT           | `MIT`        |
| Apache 2.0    | `Apache-2.0` |
| GPL 3.0       | `GPL-3.0`    |
| BSD 2-Clause  | `BSD-2-Clause` |
| BSD 3-Clause  | `BSD-3-Clause` |
| Unlicense     | `Unlicense`  |
| No license    | omit the flag |

### Common gotchas

- `--source` flag cannot be combined with `--license` — create repo first with license, then push local commits
- If the remote already has content (LICENSE, README), you must pull/merge before pushing: `git pull origin main --allow-unrelated-histories`
- Always verify with `gh repo view <org>/<repo-name>` after push

### Verification

```bash
gh repo view <org>/<repo-name>    # opens in browser
git log --oneline -3              # check commits
```
