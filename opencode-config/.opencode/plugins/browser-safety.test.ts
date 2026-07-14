/**
 * Tests for browser-safety plugin.
 *
 * Run with: bun test .opencode/plugins/browser-safety.test.ts
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
import BrowserSafetyPlugin from "./browser-safety"

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
} = (BrowserSafetyPlugin as any).testInternals as {
	killZombieChromes: () => { killed: number; errors: string[] }
	cleanBrowserProfile: () => { removed: number; errors: string[] }
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
})

describe("killZombieChromes", () => {
	test("handles no zombie processes gracefully", () => {
		const result = killZombieChromes()
		// Should not throw, should report zero killed
		expect(result.killed).toBe(0)
		expect(Array.isArray(result.errors)).toBe(true)
	})
})

describe("checkPlaywrightStatus", () => {
	test("reports installed or not-installed", () => {
		const status = checkPlaywrightStatus()
		// Must return a valid structure
		expect(typeof status.installed).toBe("boolean")
		// If installed, chromiumPath should be a string
		if (status.installed) {
			expect(typeof status.chromiumPath).toBe("string")
			expect(typeof status.chromiumExists).toBe("boolean")
		}
	})
})

describe("testInternals export", () => {
	test("all expected functions are exposed", () => {
		const internals = (BrowserSafetyPlugin as any).testInternals
		expect(internals).toBeDefined()
		expect(typeof internals.killZombieChromes).toBe("function")
		expect(typeof internals.cleanBrowserProfile).toBe("function")
		expect(typeof internals.checkPlaywrightStatus).toBe("function")
		expect(typeof internals.removeLockFilesRecursive).toBe("function")
		expect(typeof internals.BROWSER_PROFILE_DIR).toBe("string")
	})

	test("BROWSER_PROFILE_DIR matches expected path", () => {
		const expectedPath = path.join(os.homedir(), ".opencode", "browser-profile")
		expect(BROWSER_PROFILE_DIR).toBe(expectedPath)
	})
})
