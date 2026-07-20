# Worktree `rm -rf` Prohibition Fix

## Problem
LLM agents sometimes used `rm -rf` on worktree directories instead of `worktreeDelete`, orphaning their opencode sessions.

## Root Cause
1. **Tool name/behavior mismatch**: `worktreeDelete` only defers cleanup (marks for later), but the name implied immediate deletion. The command doc `worktree-delete.md` falsely claimed "directory removed, branch deleted."
2. **AGENTS.md taught `rm -rf` safety without forbidding it on worktrees**: Section on destructive commands told agents to use absolute paths for `rm -rf`, implicitly endorsing it.
3. **WORKTREE_TOOLS_PLUGIN guidance only mentioned `git worktree`, not `rm -rf`**: Agents could rationally conclude "rm -rf isn't a git command, so it's fine."
4. **No cross-session deletion**: `worktreeDelete` could only be called from within the worktree session itself. No way to clean up from parent session after a PR merge.

## Fix (July 2026)

### Plugin (opencode-worktree-enhanced) — PR #10, #11
- **`branch` parameter on `worktreeDelete`**: Enables cross-session cleanup. Call `worktreeDelete(branch: "feature/foo")` from any session.
- **`getSessionByBranch()`** in `state.ts`: Branch-based session lookup.
- **WORKTREE_TOOLS_PLUGIN guidance**: Added explicit "Never use `rm -rf` on worktree directories."
- **config.instructions and session.compacting**: Both now include the rm -rf prohibition.

### Documentation (basculer) — PR #28
- **`opencode/commands/worktree-delete.md`**: Fixed false claims, added cross-session usage, rm -rf ban.
- **`opencode/AGENTS.md`**: Added rm -rf prohibition in both safety instruction section and Worktree & Branch Cleanup section.
- **`opencode/agents/gitmaster.md`**: Added `worktreeDelete` to permissions and cleanup workflow.
