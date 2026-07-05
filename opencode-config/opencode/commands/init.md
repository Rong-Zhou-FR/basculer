---
description: scaffold project, create GitHub repo, push structure and AGENTS.md
agent: copilot
---

Scaffold $1 as a new GitHub project


## Process

### 1. Gather parameters

Ask the user for anything missing — don't guess unless the default is obvious.

| Parameter | How to get it |
|-----------|---------------|
| **Org** | `gh api user --jq '.login'` (or ask) |
| **License** | see table below; default **AGPL-3.0** |
| **Visibility** | Ask (`--public` / `--private`); default **public** |


| License       | `--license` flag |
|---------------|------------------|
| AGPL 3.0      | `AGPL-3.0`       |
| MIT           | `MIT`            |
| Apache 2.0    | `Apache-2.0`     |
| GPL 3.0       | `GPL-3.0`        |
| BSD 2-Clause  | `BSD-2-Clause`   |
| BSD 3-Clause  | `BSD-3-Clause`   |
| Unlicense     | `Unlicense`      |
| No license    | omit the flag    |

> If the repo already exists locally, skip steps 2–3 and just init git, add the remote, commit, and push.
### 2. Create GitHub repo

```bash
gh repo create "$ORG/$REPO" \
  --public \                    # or --private
  --license "$LICENSE" \
  --description "$DESC"
```

This creates the remote with a LICENSE file and minimal README.

**Gotcha**: `--source` cannot be combined with `--license`. Creating the repo first, then cloning and adding files locally, is the correct order.

### 3. Clone locally

```bash
git clone "https://github.com/$ORG/$REPO.git"
# workdir is now ./$REPO
```

### 4. Scaffold project structure

Based on **project type** and **language**, create an appropriate layout:

| Project type | Typical structure |
|---|---|
| Python library | `src/<pkg>/`, `tests/`, `pyproject.toml` |
| Python CLI | `src/<pkg>/`, `tests/`, `pyproject.toml` with `[project.scripts]` |
| Node library | `src/`, `tests/`, `package.json` |
| CLI tool (Go) | `cmd/`, `internal/`, `go.mod` |
| Web app (JS/TS) | `src/`, `public/`, `package.json`, `vite.config.ts` |
| Config / dotfiles | flat layout, `modules/` subdirs |
| Shell/bash library | `lib/`, `functions/`, `tests/` |
| Generic | `src/`, `tests/`, `docs/`, `scripts/` |

Create the matching `.gitignore` — the [github/gitignore](https://github.com/github/gitignore) repo is a good reference, but a concise project-specific one is better than a kitchen-sink copy.


### 5. Create AGENTS.md files

Fetch the templates and customise them:

- [Root `AGENTS.md`](https://raw.githubusercontent.com/Rong-Zhou-FR/ronAI/refs/heads/main/context-files/AGENTS-root-template.md)
- [Per-submodule `AGENTS.md`](https://raw.githubusercontent.com/Rong-Zhou-FR/ronAI/refs/heads/main/context-files/AGENTS-module-template.md)
  - one per submodule directory

### 6. Enhance README.md

The auto-generated README from `gh repo create` is minimal. Extend.

### 7. Commit and push


