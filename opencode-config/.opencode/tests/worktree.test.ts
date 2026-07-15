/**
 * Tests for worktree plugin validation and cleanup functions.
 *
 * Run with: bun test .opencode/tests/worktree.test.ts
 *
 * These tests verify that:
 * - validateWorktreeClean() correctly detects clean/dirty worktrees
 * - validateBranchMerged() correctly detects merged/unmerged branches
 * - removeWorktree() correctly removes worktrees
 */
import { describe, expect, test, beforeAll, afterAll } from "bun:test"
import * as fs from "node:fs"
import * as path from "node:path"
import * as os from "node:os"
import { execSync } from "node:child_process"

// Import testInternals from the worktree-enhanced plugin
import { testInternals as WorktreePlugin } from "../plugins/worktree"

// Helper: create a sandbox directory for tests
const SANDBOX = path.join(os.tmpdir(), "worktree-test-" + Date.now())

const {
	git,
	validateWorktreeClean,
	validateBranchMerged,
	removeWorktree,
} = { ...WorktreePlugin } as {
	git: (args: string[], cwd: string) => Promise<{ ok: boolean; value?: string; error?: string }>
	validateWorktreeClean: (worktreePath: string) => Promise<{ ok: boolean; error?: string }>
	validateBranchMerged: (
		repoRoot: string,
		branch: string,
		baseBranch: string,
	) => Promise<{ ok: boolean; error?: string }>
	removeWorktree: (repoRoot: string, worktreePath: string) => Promise<{ ok: boolean; error?: string }>
}

// =============================================================================
// Git Test Helpers
// =============================================================================

/**
 * Create a temporary git repository at the given path.
 * Sets up user config, creates an initial commit on the given default branch.
 */
function createGitRepo(repoPath: string, defaultBranch = "main"): void {
	execSync("git init", { cwd: repoPath })
	execSync(`git checkout -b ${defaultBranch}`, { cwd: repoPath })
	execSync('git config user.email "test@test.com"', { cwd: repoPath })
	execSync('git config user.name "Test"', { cwd: repoPath })
	// Initial commit
	fs.writeFileSync(path.join(repoPath, "README.md"), "# Test Repo")
	execSync("git add -A", { cwd: repoPath })
	execSync("git commit -m 'Initial commit'", { cwd: repoPath })
}

/**
 * Create a commit on the given branch. Creates the branch if it doesn't exist.
 */
function createCommitOnBranch(repoPath: string, branch: string, message: string): void {
	try {
		execSync(`git checkout ${branch}`, { cwd: repoPath })
	} catch {
		execSync(`git checkout -b ${branch}`, { cwd: repoPath })
	}
	// Use a safe filename (branch names may contain "/")
	const safeName = branch.replace(/\//g, "-")
	const file = path.join(repoPath, `commit-${safeName}.txt`)
	fs.writeFileSync(file, `content from ${branch}: ${Date.now()}`)
	execSync("git add -A", { cwd: repoPath })
	execSync(`git commit -m "${message}"`, { cwd: repoPath })
}

/**
 * Merge a source branch into a target branch.
 */
function mergeBranch(repoPath: string, target: string, source: string): void {
	execSync(`git checkout ${target}`, { cwd: repoPath })
	execSync(`git merge ${source} --no-edit`, { cwd: repoPath })
}

// =============================================================================
// Test Suite
// =============================================================================

describe("validateWorktreeClean", () => {
	const repoDir = path.join(SANDBOX, "clean-test-repo")

	beforeAll(() => {
		fs.mkdirSync(repoDir, { recursive: true })
		createGitRepo(repoDir)
		execSync("git checkout -b feature/test", { cwd: repoDir })
	})

	afterAll(() => {
		fs.rmSync(repoDir, { recursive: true, force: true })
	})

	test("returns ok for a clean repo", async () => {
		const result = await validateWorktreeClean(repoDir)
		expect(result.ok).toBe(true)
	})

	test("returns err for a dirty repo (modified file)", async () => {
		// Make an uncommitted change
		fs.writeFileSync(path.join(repoDir, "dirty.txt"), "uncommitted")
		const result = await validateWorktreeClean(repoDir)
		expect(result.ok).toBe(false)
		expect(result.error).toContain("uncommitted changes")
		// Clean up
		fs.unlinkSync(path.join(repoDir, "dirty.txt"))
	})

	test("returns err for a dirty repo (untracked file)", async () => {
		fs.writeFileSync(path.join(repoDir, "untracked.txt"), "new file")
		const result = await validateWorktreeClean(repoDir)
		expect(result.ok).toBe(false)
		expect(result.error).toContain("uncommitted changes")
		fs.unlinkSync(path.join(repoDir, "untracked.txt"))
	})

	test("returns err for non-existent path", async () => {
		const badPath = path.join(SANDBOX, "does-not-exist")
		const result = await validateWorktreeClean(badPath)
		expect(result.ok).toBe(false)
		expect(result.error).toContain("Failed to check worktree status")
	})

	test("returns ok after staged changes are committed", async () => {
		fs.writeFileSync(path.join(repoDir, "staged.txt"), "to commit")
		execSync("git add -A", { cwd: repoDir })
		// Staged but not committed is still dirty per `status --porcelain`
		const resultBefore = await validateWorktreeClean(repoDir)
		expect(resultBefore.ok).toBe(false)

		execSync("git commit -m 'cleanup'", { cwd: repoDir })
		const resultAfter = await validateWorktreeClean(repoDir)
		expect(resultAfter.ok).toBe(true)

		// Remove the commit for test isolation
		execSync("git reset --hard HEAD~1", { cwd: repoDir })
	})

	test("clean repo remains clean after successive calls", async () => {
		const r1 = await validateWorktreeClean(repoDir)
		expect(r1.ok).toBe(true)
		const r2 = await validateWorktreeClean(repoDir)
		expect(r2.ok).toBe(true)
	})
})

describe("validateBranchMerged", () => {
	const repoDir = path.join(SANDBOX, "merge-test-repo")

	beforeAll(() => {
		fs.mkdirSync(repoDir, { recursive: true })
		createGitRepo(repoDir, "main")

		// Create a feature branch with commits
		createCommitOnBranch(repoDir, "feature/merged", "feat: work on merged branch")
		createCommitOnBranch(repoDir, "feature/merged", "feat: more work on merged branch")
		// Merge it into main
		mergeBranch(repoDir, "main", "feature/merged")

		// Create another feature branch that will NOT be merged
		createCommitOnBranch(repoDir, "feature/unmerged", "feat: work on unmerged branch")
		// Stay on this unmerged branch
	})

	afterAll(() => {
		fs.rmSync(repoDir, { recursive: true, force: true })
	})

	test("returns ok for a merged branch", async () => {
		const result = await validateBranchMerged(repoDir, "feature/merged", "main")
		expect(result.ok).toBe(true)
	})

	test("returns err for an unmerged branch", async () => {
		const result = await validateBranchMerged(repoDir, "feature/unmerged", "main")
		expect(result.ok).toBe(false)
		expect(result.error).toContain("NOT fully merged")
		expect(result.error).toContain("feature/unmerged")
		expect(result.error).toContain("main")
	})

	test("returns err for non-existent branch", async () => {
		const result = await validateBranchMerged(repoDir, "feature/nonexistent", "main")
		expect(result.ok).toBe(false)
	})

	test("returns err for non-existent base branch", async () => {
		const result = await validateBranchMerged(repoDir, "feature/merged", "nonexistent")
		expect(result.ok).toBe(false)
	})

	test("returns err for non-existent repo path", async () => {
		const badPath = path.join(SANDBOX, "no-repo-here")
		const result = await validateBranchMerged(badPath, "feature/merged", "main")
		expect(result.ok).toBe(false)
	})
})

describe("git helper", () => {
	const repoDir = path.join(SANDBOX, "git-helper-test")

	beforeAll(() => {
		fs.mkdirSync(repoDir, { recursive: true })
		createGitRepo(repoDir)
	})

	afterAll(() => {
		fs.rmSync(repoDir, { recursive: true, force: true })
	})

	test("git() returns ok for successful commands", async () => {
		const result = await git(["rev-parse", "--verify", "main"], repoDir)
		expect(result.ok).toBe(true)
		expect(result.value).toBeDefined()
	})

	test("git() returns err for failing commands", async () => {
		const result = await git(["rev-parse", "--verify", "nonexistent-branch"], repoDir)
		expect(result.ok).toBe(false)
	})

	test("git() returns err for non-existent cwd", async () => {
		const result = await git(["status"], "/nonexistent/path")
		expect(result.ok).toBe(false)
	})
})

describe("removeWorktree", () => {
	const mainRepo = path.join(SANDBOX, "wt-remove-main")
	const worktreesDir = path.join(SANDBOX, "wt-remove-worktrees")

	beforeAll(() => {
		// Create main repo
		fs.mkdirSync(mainRepo, { recursive: true })
		createGitRepo(mainRepo, "main")

		// Create a worktree from the main repo
		fs.mkdirSync(worktreesDir, { recursive: true })

		execSync(
			`git worktree add -b feature/wt-remove ${path.join(worktreesDir, "feature-wt-remove")} main`,
			{ cwd: mainRepo },
		)
		// The worktree is clean and valid
	})

	afterAll(() => {
		// Clean up any leftover worktrees before removing main
		try {
			const wtPath = path.join(worktreesDir, "feature-wt-remove")
			if (fs.existsSync(wtPath)) {
				execSync(`git worktree remove --force "${wtPath}"`, { cwd: mainRepo })
			}
		} catch {
			// Best-effort cleanup
		}
		fs.rmSync(worktreesDir, { recursive: true, force: true })
		fs.rmSync(mainRepo, { recursive: true, force: true })
	})

	test("removes a valid worktree", async () => {
		const wtPath = path.join(worktreesDir, "feature-wt-remove")
		expect(fs.existsSync(wtPath)).toBe(true)

		const result = await removeWorktree(mainRepo, wtPath)
		expect(result.ok).toBe(true)

		// Verify worktree directory no longer exists as a git worktree
		// (the directory itself may be cleaned by git worktree remove)
	})

	test("returns err for non-existent worktree path", async () => {
		const result = await removeWorktree(mainRepo, "/nonexistent/worktree/path")
		expect(result.ok).toBe(false)
	})
})

describe("end-to-end: clean repo with merged branch passes validation", () => {
	const repoDir = path.join(SANDBOX, "e2e-clean-merged")

	beforeAll(() => {
		fs.mkdirSync(repoDir, { recursive: true })
		createGitRepo(repoDir, "main")
		// Create feature, commit, merge
		createCommitOnBranch(repoDir, "feature/e2e", "feat: e2e test commit")
		mergeBranch(repoDir, "main", "feature/e2e")
		// Stay on main, repo is clean
	})

	afterAll(() => {
		fs.rmSync(repoDir, { recursive: true, force: true })
	})

	test("clean + merged = both validations pass", async () => {
		const clean = await validateWorktreeClean(repoDir)
		expect(clean.ok).toBe(true)

		const merged = await validateBranchMerged(repoDir, "feature/e2e", "main")
		expect(merged.ok).toBe(true)
	})
})

describe("end-to-end: dirty repo with merged branch fails clean validation", () => {
	const repoDir = path.join(SANDBOX, "e2e-dirty-merged")

	beforeAll(() => {
		fs.mkdirSync(repoDir, { recursive: true })
		createGitRepo(repoDir, "main")
		createCommitOnBranch(repoDir, "feature/dirty-merged", "feat: dirty merged commit")
		mergeBranch(repoDir, "main", "feature/dirty-merged")
		// Dirty the repo
		fs.writeFileSync(path.join(repoDir, "oops.txt"), "forgot to commit this")
	})

	afterAll(() => {
		fs.rmSync(repoDir, { recursive: true, force: true })
	})

	test("merged but dirty = clean fails, merged passes", async () => {
		const clean = await validateWorktreeClean(repoDir)
		expect(clean.ok).toBe(false)
		expect(clean.error).toContain("uncommitted changes")

		const merged = await validateBranchMerged(repoDir, "feature/dirty-merged", "main")
		expect(merged.ok).toBe(true)
	})
})

describe("end-to-end: clean repo with unmerged branch fails merge validation", () => {
	const repoDir = path.join(SANDBOX, "e2e-clean-unmerged")

	beforeAll(() => {
		fs.mkdirSync(repoDir, { recursive: true })
		createGitRepo(repoDir, "main")
		createCommitOnBranch(repoDir, "feature/clean-unmerged", "feat: unmerged commit")
		// Stay on feature branch, don't merge, repo is clean
	})

	afterAll(() => {
		fs.rmSync(repoDir, { recursive: true, force: true })
	})

	test("clean but unmerged = clean passes, merged fails", async () => {
		// Check clean (it should be clean on the feature branch)
		const clean = await validateWorktreeClean(repoDir)
		expect(clean.ok).toBe(true)

		// Check merged (should fail — branch not merged)
		const merged = await validateBranchMerged(repoDir, "feature/clean-unmerged", "main")
		expect(merged.ok).toBe(false)
		expect(merged.error).toContain("NOT fully merged")
	})
})

describe("testInternals export", () => {
	test("all expected worktree validation functions are exposed", () => {
		const internals = WorktreePlugin
		expect(internals).toBeDefined()
		expect(typeof internals.validateWorktreeClean).toBe("function")
		expect(typeof internals.validateBranchMerged).toBe("function")
		expect(typeof internals.removeWorktree).toBe("function")
		expect(typeof internals.git).toBe("function")
	})

	test("existing internals are still exposed", () => {
		const internals = WorktreePlugin
		expect(typeof internals.copyFiles).toBe("function")
		expect(typeof internals.symlinkDirs).toBe("function")
	})
})
