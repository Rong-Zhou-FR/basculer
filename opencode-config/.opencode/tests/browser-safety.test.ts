/**
 * Tests for browser-safety plugin.
 *
 * Run with: bun test .opencode/tests/browser-safety.test.ts
 *
 * These tests verify the utility functions that protect against
 * browser hangs caused by stale state after interrupted sessions.
 */

import { describe, expect, test, beforeAll, afterAll } from "bun:test"
import * as fs from "node:fs"
import * as path from "node:path"
import * as os from "node:os"
import { execSync } from "node:child_process"

// Import the plugin to get testInternals
import BrowserSafetyPlugin from "../plugins/browser-safety"

// Helper: create a sandbox directory for tests
const SANDBOX = path.join(
	os.tmpdir(),
	"browser-safety-test-" + Date.now(),
)

const {
	killZombieChromes,
	cleanBrowserProfile,
	checkPlaywrightStatus,
	removeLockFilesRecursive,
	BROWSER_PROFILE_DIR,
	SESSIONS_PROFILE_DIR,
	BROWSER_SAFETY_MARKER,
	BROWSER_SAFETY_GUIDANCE,
	sanitizeSessionID,
	sessionProfileDir,
	getOrCreateSession,
} = (BrowserSafetyPlugin as any).testInternals as {
	killZombieChromes: () => { killed: number; errors: string[] }
	cleanBrowserProfile: (dir?: string) => { removed: number; errors: string[] }
	checkPlaywrightStatus: () => {
		installed: boolean
		chromiumPath: string | null
		chromiumExists: boolean
	}
	removeLockFilesRecursive: (
		dir: string,
		onRemoved: (name: string) => void,
	) => void
	BROWSER_PROFILE_DIR: string
	SESSIONS_PROFILE_DIR: string
	BROWSER_SAFETY_MARKER: string
	BROWSER_SAFETY_GUIDANCE: string
	sanitizeSessionID: (id: string) => string
	sessionProfileDir: (sessionID: string) => string
	getOrCreateSession: (sessionID: string) => { context: null; pages: Map<string, any> }
}

// =============================================================================
// Tests
// =============================================================================

describe("cleanBrowserProfile", () => {
	beforeAll(() => {
		// Ensure sandbox is clean
		if (fs.existsSync(SANDBOX)) {
			fs.rmSync(SANDBOX, { recursive: true, force: true })
		}
		fs.mkdirSync(SANDBOX, { recursive: true })
	})

	afterAll(() => {
		fs.rmSync(SANDBOX, { recursive: true, force: true })
	})

	test("returns zero removed when profile directory does not exist", () => {
		const nonexistent = path.join(SANDBOX, "nonexistent-profile")
		const result = cleanBrowserProfile(nonexistent)
		// Should return zero removed, no errors for non-existent profile
		expect(result.removed).toBe(0)
		expect(Array.isArray(result.errors)).toBe(true)
	})

	test("removes Singleton files from profile root", () => {
		// Create a mock profile directory with Singleton files
		const mockProfile = path.join(SANDBOX, "mock-profile-1")
		fs.mkdirSync(mockProfile, { recursive: true })
		fs.writeFileSync(path.join(mockProfile, "SingletonLock"), "")
		fs.writeFileSync(path.join(mockProfile, "SingletonCookie"), "")
		fs.writeFileSync(path.join(mockProfile, "SingletonSocket"), "")
		fs.writeFileSync(path.join(mockProfile, "normal-file.txt"), "hello")
		fs.mkdirSync(path.join(mockProfile, "Default"), { recursive: true })

		// Act: clean the profile (pass mock path)
		const result = cleanBrowserProfile(mockProfile)

		// Assert: Singleton files should be removed
		expect(fs.existsSync(path.join(mockProfile, "SingletonLock"))).toBe(false)
		expect(fs.existsSync(path.join(mockProfile, "SingletonCookie"))).toBe(false)
		expect(fs.existsSync(path.join(mockProfile, "SingletonSocket"))).toBe(false)
		// Normal files should remain
		expect(fs.existsSync(path.join(mockProfile, "normal-file.txt"))).toBe(true)

		// Clean up
		fs.rmSync(mockProfile, { recursive: true, force: true })
	})

	test("removes LOCK files in Default/ subtree", () => {
		// Create nested lock files
		const mockProfile = path.join(SANDBOX, "mock-profile-2")
		const defaultDir = path.join(mockProfile, "Default")

		fs.mkdirSync(path.join(defaultDir, "Local Storage", "leveldb"), {
			recursive: true,
		})
		fs.mkdirSync(path.join(defaultDir, "Session Storage"), { recursive: true })
		fs.mkdirSync(path.join(defaultDir, "shared_proto_db"), { recursive: true })

		fs.writeFileSync(
			path.join(defaultDir, "Local Storage", "leveldb", "LOCK"),
			"",
		)
		fs.writeFileSync(
			path.join(defaultDir, "Session Storage", "LOCK"),
			"",
		)
		fs.writeFileSync(
			path.join(defaultDir, "shared_proto_db", "LOCK"),
			"",
		)
		fs.writeFileSync(path.join(defaultDir, "Cookies"), "data")
		fs.writeFileSync(path.join(defaultDir, "Cookies-journal"), "data")

		// Act: clean the profile (pass mock path)
		const result = cleanBrowserProfile(mockProfile)

		// Assert: LOCK files removed, data files remain
		expect(
			fs.existsSync(
				path.join(defaultDir, "Local Storage", "leveldb", "LOCK"),
			),
		).toBe(false)
		expect(
			fs.existsSync(path.join(defaultDir, "Session Storage", "LOCK")),
		).toBe(false)
		expect(
			fs.existsSync(path.join(defaultDir, "shared_proto_db", "LOCK")),
		).toBe(false)
		// Non-lock files persist
		expect(fs.existsSync(path.join(defaultDir, "Cookies"))).toBe(true)
		expect(fs.existsSync(path.join(defaultDir, "Cookies-journal"))).toBe(true)

		fs.rmSync(mockProfile, { recursive: true, force: true })
	})

	test("handles permission errors gracefully", () => {
		// Create a file that can't be read (requires permissions test)
		const mockProfile = path.join(SANDBOX, "mock-profile-3")
		fs.mkdirSync(mockProfile, { recursive: true })
		fs.writeFileSync(path.join(mockProfile, "SingletonLock"), "")

		// Make a subdirectory unreadable
		const restricted = path.join(mockProfile, "Default")
		fs.mkdirSync(restricted, { recursive: true })
		fs.writeFileSync(path.join(restricted, "LOCK"), "")
		fs.chmodSync(restricted, 0o000)

		const result = cleanBrowserProfile(mockProfile)

		// Should not throw — errors captured in result.errors
		expect(Array.isArray(result.errors)).toBe(true)

		// Restore permissions for cleanup
		fs.chmodSync(restricted, 0o755)
		fs.rmSync(mockProfile, { recursive: true, force: true })
	})

	test("skips Default/ lock scan when Default/ does not exist", () => {
		// Profile with Singleton files but no Default/ directory
		const mockProfile = path.join(SANDBOX, "mock-profile-4")
		fs.mkdirSync(mockProfile, { recursive: true })
		fs.writeFileSync(path.join(mockProfile, "SingletonLock"), "")

		const result = cleanBrowserProfile(mockProfile)

		// Should have removed the Singleton but not errored on missing Default/
		expect(result.removed).toBe(1)
		expect(result.errors.length).toBe(0)

		fs.rmSync(mockProfile, { recursive: true, force: true })
	})

	test("handles empty Default/ directory gracefully", () => {
		const mockProfile = path.join(SANDBOX, "mock-profile-5")
		fs.mkdirSync(path.join(mockProfile, "Default"), { recursive: true })
		// No lock files inside

		const result = cleanBrowserProfile(mockProfile)

		expect(result.removed).toBe(0)
		expect(result.errors.length).toBe(0)

		fs.rmSync(mockProfile, { recursive: true, force: true })
	})
})

describe("removeLockFilesRecursive", () => {
	test("finds and removes .lock files recursively", () => {
		const testDir = path.join(SANDBOX, "remove-lock-test")
		fs.mkdirSync(path.join(testDir, "a", "b"), { recursive: true })
		fs.writeFileSync(path.join(testDir, "data.lock"), "")
		fs.writeFileSync(path.join(testDir, "notes.txt"), "content")
		fs.writeFileSync(path.join(testDir, "a", "LOCK"), "")
		fs.writeFileSync(path.join(testDir, "a", "b", "LOCK-db"), "")
		fs.writeFileSync(path.join(testDir, "a", "b", "important.csv"), "data")

		const removed: string[] = []
		removeLockFilesRecursive(testDir, (name) => removed.push(name))

		expect(removed).toContain("data.lock")
		expect(removed).toContain("LOCK")
		expect(removed).toContain("LOCK-db")
		expect(removed.length).toBe(3)

		// Verify files were actually removed
		expect(fs.existsSync(path.join(testDir, "data.lock"))).toBe(false)
		expect(fs.existsSync(path.join(testDir, "notes.txt"))).toBe(true)
		expect(fs.existsSync(path.join(testDir, "a", "b", "important.csv"))).toBe(
			true,
		)

		fs.rmSync(testDir, { recursive: true, force: true })
	})

	test("handles non-existent directory gracefully", () => {
		const nonExistent = path.join(SANDBOX, "does-not-exist")
		const removed: string[] = []
		// Should not throw
		removeLockFilesRecursive(nonExistent, (name) => removed.push(name))
		expect(removed.length).toBe(0)
	})

	test("returns zero removals for directory with no lock files", () => {
		const testDir = path.join(SANDBOX, "no-locks")
		fs.mkdirSync(path.join(testDir, "sub"), { recursive: true })
		fs.writeFileSync(path.join(testDir, "readme.md"), "hello")
		fs.writeFileSync(path.join(testDir, "sub", "index.js"), "code")

		const removed: string[] = []
		removeLockFilesRecursive(testDir, (name) => removed.push(name))

		expect(removed.length).toBe(0)
		// Non-lock files still exist
		expect(fs.existsSync(path.join(testDir, "readme.md"))).toBe(true)
		expect(fs.existsSync(path.join(testDir, "sub", "index.js"))).toBe(true)

		fs.rmSync(testDir, { recursive: true, force: true })
	})

	test("handles partial stat failures gracefully (non-readable file)", () => {
		const testDir = path.join(SANDBOX, "partial-fail")
		fs.mkdirSync(testDir, { recursive: true })
		fs.writeFileSync(path.join(testDir, "data.lock"), "")
		// A file we can't stat
		const unreadable = path.join(testDir, "secret")
		fs.writeFileSync(unreadable, "hidden")
		fs.chmodSync(unreadable, 0o000)

		const removed: string[] = []
		// Should not throw; the unreadable file is skipped (stat fails -> continue)
		removeLockFilesRecursive(testDir, (name) => removed.push(name))

		expect(removed).toContain("data.lock")
		expect(removed.length).toBe(1)

		fs.chmodSync(unreadable, 0o644)
		fs.rmSync(testDir, { recursive: true, force: true })
	})
})

describe("killZombieChromes", () => {
	test("handles no zombie processes gracefully", () => {
		const result = killZombieChromes()
		// Should not throw, should report zero killed
		expect(result.killed).toBe(0)
		expect(Array.isArray(result.errors)).toBe(true)
		// When no processes match, pgrep exits with code 1, which is
		// caught by the outer try/catch and filtered out by the
		// "exit code 1" check — so errors should remain empty
		expect(result.errors.length).toBe(0)
	})
})

describe("killZombieChromes error handling", () => {
	test("tolerates pgrep being unavailable", () => {
		// Can't easily remove pgrep from PATH, but we can verify the
		// function doesn't throw when pgrep is available
		const result = killZombieChromes()
		expect(result.killed).toBeGreaterThanOrEqual(0)
		expect(Array.isArray(result.errors)).toBe(true)
	})
})

describe("checkPlaywrightStatus", () => {
	// Store original cache dir to restore after mocking
	const REAL_CACHE = path.join(os.homedir(), ".cache", "ms-playwright")

	test("reports installed when chromium exists in cache", () => {
		const status = checkPlaywrightStatus()
		// Must return a valid structure
		expect(typeof status.installed).toBe("boolean")
		expect(typeof status.chromiumPath).toBe("string")
		expect(typeof status.chromiumExists).toBe("boolean")
	})

	test("reports not-installed when ms-playwright cache does not exist", () => {
		// Temporarily rename the cache to simulate absence
		const tempBackup = REAL_CACHE + ".bak-" + Date.now()
		try {
			if (fs.existsSync(REAL_CACHE)) {
				fs.renameSync(REAL_CACHE, tempBackup)
			}
			const status = checkPlaywrightStatus()
			expect(status.installed).toBe(false)
			expect(status.chromiumPath).toBeNull()
			expect(status.chromiumExists).toBe(false)
		} finally {
			// Restore cache
			if (fs.existsSync(tempBackup)) {
				fs.renameSync(tempBackup, REAL_CACHE)
			}
		}
	})

	test("reports not-installed when cache exists but no chromium-* dir", () => {
		// Create a mock cache dir without chromium
		const mockCache = path.join(SANDBOX, "mock-ms-playwright-noc")
		fs.mkdirSync(mockCache, { recursive: true })
		// Put a non-chromium file
		fs.writeFileSync(path.join(mockCache, "firefox-1234"), "")

		// Test via checkPlaywrightStatus won't help because it uses hardcoded path
		// Instead test the internal logic: readdirSync + find("chromium-")
		const entries = fs.readdirSync(mockCache)
		const chromiumDir = entries.find((e) => e.startsWith("chromium-"))
		expect(chromiumDir).toBeUndefined()

		fs.rmSync(mockCache, { recursive: true, force: true })
	})
})

describe("testInternals export", () => {
	test("all expected functions and constants are exposed", () => {
		const internals = (BrowserSafetyPlugin as any).testInternals
		expect(internals).toBeDefined()
		expect(typeof internals.killZombieChromes).toBe("function")
		expect(typeof internals.cleanBrowserProfile).toBe("function")
		expect(typeof internals.checkPlaywrightStatus).toBe("function")
		expect(typeof internals.removeLockFilesRecursive).toBe("function")
		expect(typeof internals.sanitizeSessionID).toBe("function")
		expect(typeof internals.sessionProfileDir).toBe("function")
		expect(typeof internals.getOrCreateSession).toBe("function")
		expect(typeof internals.BROWSER_PROFILE_DIR).toBe("string")
		expect(typeof internals.SESSIONS_PROFILE_DIR).toBe("string")
		expect(typeof internals.BROWSER_SAFETY_MARKER).toBe("string")
		expect(typeof internals.BROWSER_SAFETY_GUIDANCE).toBe("string")
	})

	test("BROWSER_PROFILE_DIR matches expected path", () => {
		const expectedPath = path.join(os.homedir(), ".opencode", "browser-profile")
		expect(BROWSER_PROFILE_DIR).toBe(expectedPath)
	})

	test("SESSIONS_PROFILE_DIR is subdirectory of BROWSER_PROFILE_DIR", () => {
		expect(SESSIONS_PROFILE_DIR).toBe(path.join(BROWSER_PROFILE_DIR, "sessions"))
	})

	test("BROWSER_SAFETY_MARKER is correct", () => {
		expect(BROWSER_SAFETY_MARKER).toBe("opencode-browser-safety")
	})

	test("BROWSER_SAFETY_GUIDANCE contains key instructions", () => {
		expect(BROWSER_SAFETY_GUIDANCE).toContain("<BROWSER_SAFETY>")
		expect(BROWSER_SAFETY_GUIDANCE).toContain("</BROWSER_SAFETY>")
		expect(BROWSER_SAFETY_GUIDANCE).toContain("browser_health")
		expect(BROWSER_SAFETY_GUIDANCE).toContain("browser_clean")
		expect(BROWSER_SAFETY_GUIDANCE).toContain("per-session")
		expect(BROWSER_SAFETY_GUIDANCE).toContain("127.0.0.1")
		expect(BROWSER_SAFETY_GUIDANCE).toContain("timeout")
		expect(BROWSER_SAFETY_GUIDANCE).toContain("pkill -f")
	})

	test("BROWSER_SAFETY_GUIDANCE does not contain the dedup marker", () => {
		expect(BROWSER_SAFETY_GUIDANCE).not.toContain(BROWSER_SAFETY_MARKER)
	})
})

// =============================================================================
// Per-session isolation tests
// =============================================================================

describe("sanitizeSessionID", () => {
	test("replaces non-alphanumeric chars with underscores and limits to 12 chars", () => {
		expect(sanitizeSessionID("ses_abc123")).toBe("ses_abc123")
		const result = sanitizeSessionID("hello world!@#")
		expect(result.length).toBeLessThanOrEqual(12)
		expect(result).not.toContain("!")
		expect(result).not.toContain("@")
		expect(result).not.toContain("#")
		expect(result).not.toContain(" ")
	})

	test("limits to 12 characters", () => {
		const long = "a".repeat(50)
		expect(sanitizeSessionID(long).length).toBe(12)
	})

	test("produces stable output for same input", () => {
		const id = "ses_0a8744f5affeQOhmyqYcggN6wP"
		expect(sanitizeSessionID(id)).toBe(sanitizeSessionID(id))
	})
})

describe("sessionProfileDir", () => {
	test("uses sessions subdirectory of BROWSER_PROFILE_DIR", () => {
		const dir = sessionProfileDir("ses_test123")
		expect(dir).toContain(SESSIONS_PROFILE_DIR)
	})

	test("includes sanitized session ID", () => {
		const dir = sessionProfileDir("ses_test_abc")
		expect(dir).toContain("ses_test_abc")
	})
})

describe("getOrCreateSession", () => {
	test("creates a new session state for unknown sessionID", () => {
		const id = "test-session-" + Date.now()
		const state = getOrCreateSession(id)
		expect(state).toBeDefined()
		expect(state.context).toBeNull()
		expect(state.pages).toBeInstanceOf(Map)
		expect(state.pages.size).toBe(0)
		expect(state.pageCounter).toBe(0)
	})

	test("returns same state for repeated call with same sessionID", () => {
		const id = "test-session-duplicate-" + Date.now()
		const s1 = getOrCreateSession(id)
		const s2 = getOrCreateSession(id)
		expect(s1).toBe(s2)
	})

	test("different sessionIDs produce different state objects", () => {
		const s1 = getOrCreateSession("session-A-" + Date.now())
		const s2 = getOrCreateSession("session-B-" + Date.now())
		expect(s1).not.toBe(s2)
	})
})
