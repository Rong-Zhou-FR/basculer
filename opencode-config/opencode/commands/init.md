---
description: scaffold project, create GitHub repo, push structure and AGENTS.md (interactive - asks for confirmation at every step)
agent: copilot
---

Scaffold $1 as new GitHub project(s) — **ask for user confirmation at every decision point**. Do not proceed to the next step until the user explicitly approves the current one.

## Principle

**Do not guess or act autonomously.** At each step, propose concrete options to the user via the `question` tool, let them pick or customise, then act only on explicit approval.

---

## Step-by-step workflow

### Step 1: Propose repo metadata → ask user

Propose the following to the user using a single `question` call:

| Field | How to determine the default |
|-------|------------------------------|
| **Repo name** | Derive from `$1` (the argument to the `init` command); if `$1` is unclear, ask what the project does first |
| **Description** | One sentence summarising what the project does |
| **Visibility** | `public` (recommended for OSS) or `private` |
| **License** | See table below; default **AGPL-3.0** |
| **Org** | Get current GitHub user: `gh api user --jq '.login'` (default), or let the user specify a different org |

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

**Wait for user approval before proceeding.** If the user changes any field, update your proposal and ask again until agreement is reached.

### Step 2: Create GitHub repo (only on explicit approval)

Once the user has approved all metadata:

```bash
gh repo create "$ORG/$REPO" \
  --public \                    # or --private
  --license "$LICENSE" \
  --description "$DESC"
```

**Gotcha**: `--source` cannot be combined with `--license`. Creating the repo first and then cloning locally is the correct order.

Enable auto-delete of merged PR branches:

```bash
gh api -X PATCH "repos/$ORG/$REPO" -f delete_branch_on_merge=true
```

Clone locally:

```bash
git clone "https://github.com/$ORG/$REPO.git"
# workdir is now ./$REPO
```

**Tell the user the repo was created and confirm you're ready to propose an architecture.** Wait for a go-ahead.

### Step 3: Propose repo architecture → ask user

Propose an architecture to the user via `question`. Base the proposal on the project type and language (inferred from the repo name/description/your best judgment), but present it as a suggestion to approve or modify:

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

**Present your concrete proposal** — don't just list options. Say something like:

> *"I recommend a Python CLI tool layout: `src/<pkg>/`, `tests/`, `pyproject.toml` with `[project.scripts]`. The `.gitignore` would target Python. Does this work?"*

Include an option for the user to describe their own structure if none of your suggestions fit.

**Wait for explicit approval.** If the user modifies the proposal, update and re-present until agreed.

### Step 4: Scaffold, write AGENTS.md, commit & push (only on approval)

Once architecture is approved:

1. **Scaffold** the directory structure and files as agreed
   - Create the matching `.gitignore` — concise and project-specific
       - **DO NOT ignore**: 
         - `.opencode/`: agents, commands, skills, local plugins, and project-level config live here and are worth sharing across clones.
       - **DO ignore**: 
         - `**/worktree.json*` — auto-generated artifact from the `opencode-worktree-enhanced` plugin
2. **Create AGENTS.md files**
   - Fetch templates:
     - [Root `AGENTS.md`](https://raw.githubusercontent.com/Rong-Zhou-FR/ronAI/refs/heads/main/context-files/AGENTS-root-template.md)
     - [Per-submodule `AGENTS.md`](https://raw.githubusercontent.com/Rong-Zhou-FR/ronAI/refs/heads/main/context-files/AGENTS-module-template.md)
       - one per submodule directory
   - Customise to match the project's actual structure
3. **Enhance README.md** beyond the auto-generated one
4. **Commit and push**
   - Conventional commit message: `feat: initial scaffold with AGENTS.md`
5. **Tell the user the project is live** with the clone URL

---

## If the repo already exists locally

If the target directory already exists and is a git repo, skip Steps 1–3 and just init git (if needed), add the remote, commit, and push. Ask the user before taking any action.
