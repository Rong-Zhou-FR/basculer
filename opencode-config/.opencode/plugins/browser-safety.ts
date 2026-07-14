/**
 * Browser Safety Plugin
 *
 * Safety wrapper for the opencode-browser-plugin (v1.0.1).
 * Prevents hangs by cleaning stale browser state before operations,
 * provides diagnostic tools, and handles recovery on failures.
 *
 * Root cause addressed:
 *   The browser plugin uses `chromium.launchPersistentContext()` with a
 *   fixed profile directory (~/.opencode/browser-profile/). When an opencode
 *   session is interrupted (tool timeout, user interruption, agent restart),
 *   the Chromium process is killed ungracefully, leaving the profile in an
 *   inconsistent state. The plugin's `ensureBrowser()` never validates that
 *   `state.context` is alive, and it ignores the `context.abort` signal from
 *   opencode's ToolContext. Subsequent browser operations silently target
 *   a dead context, causing all actions to hang indefinitely.
 *
 * This plugin must be loaded AFTER opencode-browser-plugin in the plugin array.
 *
 * @module browser-safety
 */

import { type Plugin, tool } from "@opencode-ai/plugin"
import * as fs from "node:fs"
import * as path from "node:path"
import * as os from "node:os"
import { execSync, spawnSync } from "node:child_process"

// =============================================================================
// CONSTANTS
// =============================================================================

/** Browser profile directory used by opencode-browser-plugin */
const BROWSER_PROFILE_DIR = path.join(os.homedir(), ".opencode", "browser-profile")

/** Timeout for killing browser processes (ms) */
const KILL_TIMEOUT_MS = 5000

// =============================================================================
// UTILITY FUNCTIONS
// =============================================================================

/**
 * Kill all orphaned Chromium and Playwright browser processes.
 * Uses SIGTERM first, then SIGKILL after a short grace period.
 * This is safe because it only targets processes launched by
 * Playwright (identifiable by their command-line arguments).
 */
function killZombieChromes(): { killed: number; errors: string[] } {
	const errors: string[] = []
	let killed = 0

	try {
		// Find all Chromium processes launched by Playwright
		// NOTE: pattern MUST NOT start with "--" or pgrep treats it as an option flag.
		const result = spawnSync(
			"pgrep",
			[
				"-f",
				// Match Chromium processes with Playwright-specific args
				// - remote-debugging-pipe: all Playwright Chromium processes use this
				// - chrome-headless-shell: headless chromium binary path
				"remote-debugging-pipe|chrome-headless-shell|chrome-linux64/chrome",
			],
			{ encoding: "utf8", timeout: KILL_TIMEOUT_MS },
		)

		if (result.status === 0 && result.stdout) {
			const pids = result.stdout.trim().split("\n").filter(Boolean)

			for (const pid of pids) {
				try {
					// Try graceful kill first
					process.kill(parseInt(pid), "SIGTERM")
					killed++
				} catch (e: unknown) {
					const msg = e instanceof Error ? e.message : String(e)
					if (!msg.includes("ESRCH")) {
						// ESRCH means process already dead - not an error
						errors.push(`SIGTERM ${pid}: ${msg}`)
					}
				}
			}

			// Give processes a moment to exit gracefully
			if (killed > 0) {
				const waitResult = spawnSync("sleep", ["1"], { timeout: 2000 })
				if (waitResult.error) {
					errors.push(`sleep failed: ${waitResult.error.message}`)
				}
			}

			// Force kill any remaining
			const result2 = spawnSync(
				"pgrep",
				[
					"-f",
					"remote-debugging-pipe|chrome-headless-shell|chrome-linux64/chrome",
				],
				{ encoding: "utf8", timeout: 2000 },
			)

			if (result2.status === 0 && result2.stdout) {
				const remaining = result2.stdout.trim().split("\n").filter(Boolean)
				for (const pid of remaining) {
					try {
						process.kill(parseInt(pid), "SIGKILL")
						killed++
					} catch (e: unknown) {
						const msg = e instanceof Error ? e.message : String(e)
						if (!msg.includes("ESRCH")) {
							errors.push(`SIGKILL ${pid}: ${msg}`)
						}
					}
				}
			}
		}
	} catch (e: unknown) {
		const msg = e instanceof Error ? e.message : String(e)
		// pgrep exits with code 1 when no processes match - not an error
		if (!msg.includes("exit code 1") && !msg.includes("status 1")) {
			errors.push(`pgrep failed: ${msg}`)
		}
	}

	return { killed, errors }
}

/**
 * Clean the browser profile directory of stale lock files.
 * Removes Singleton*, *.lock files, and LevelDB LOCK files that
 * can cause Chromium to hang on startup after an interrupted session.
 *
 * Returns a summary of what was cleaned.
 */
/**
 * Clean the browser profile directory of stale lock files.
 *
 * @param profileDir - Directory to clean (defaults to BROWSER_PROFILE_DIR).
 *   The default parameter allows the real profile path to be overridden in tests.
 * @returns Summary of what was cleaned.
 */
function cleanBrowserProfile(
	profileDir?: string,
): { removed: number; errors: string[] } {
	const targetDir = profileDir ?? BROWSER_PROFILE_DIR
	const errors: string[] = []
	let removed = 0

	if (!fs.existsSync(targetDir)) {
		return { removed: 0, errors: [] }
	}

	// Pattern 1: Chromium Singleton* files at the profile root
	try {
		const entries = fs.readdirSync(targetDir)
		for (const entry of entries) {
			if (entry.startsWith("Singleton")) {
				const fullPath = path.join(targetDir, entry)
				try {
					fs.unlinkSync(fullPath)
					removed++
				} catch (e: unknown) {
					const msg = e instanceof Error ? e.message : String(e)
					if (!msg.includes("ENOENT")) {
						errors.push(`Failed to remove ${entry}: ${msg}`)
					}
				}
			}
		}
	} catch (e: unknown) {
		const msg = e instanceof Error ? e.message : String(e)
		errors.push(`Failed to read profile directory: ${msg}`)
	}

	// Pattern 2: *.lock and LOCK files recursively inside Default/
	const defaultDir = path.join(targetDir, "Default")
	if (fs.existsSync(defaultDir)) {
		try {
			removeLockFilesRecursive(defaultDir, (name) => {
				removed++
			})
		} catch (e: unknown) {
			const msg = e instanceof Error ? e.message : String(e)
			errors.push(`Failed to clean Default/ locks: ${msg}`)
		}
	}

	return { removed, errors }
}

/**
 * Recursively find and remove lock files in a directory tree.
 * Matches files ending in .lock, named LOCK, or named LOCK-*.
 */
function removeLockFilesRecursive(
	dir: string,
	onRemoved: (name: string) => void,
): void {
	let entries: string[]
	try {
		entries = fs.readdirSync(dir)
	} catch {
		return // Directory doesn't exist or can't be read
	}

	for (const entry of entries) {
		const fullPath = path.join(dir, entry)

		let stat: fs.Stats
		try {
			stat = fs.statSync(fullPath)
		} catch {
			continue
		}

		if (stat.isDirectory()) {
			// Recurse into subdirectories
			removeLockFilesRecursive(fullPath, onRemoved)
		} else if (
			entry.endsWith(".lock") ||
			entry === "LOCK" ||
			entry.startsWith("LOCK-")
		) {
			try {
				fs.unlinkSync(fullPath)
				onRemoved(entry)
			} catch {
				// Best effort - file may be in use
			}
		}
	}
}

/**
 * Check if Playwright browsers are installed and available.
 * Returns a formatted string with the status.
 */
function checkPlaywrightStatus(): {
	installed: boolean
	chromiumPath: string | null
	chromiumExists: boolean
} {
	try {
		// Check for the Playwright browsers cache
		const cacheDir = path.join(os.homedir(), ".cache", "ms-playwright")
		if (!fs.existsSync(cacheDir)) {
			return { installed: false, chromiumPath: null, chromiumExists: false }
		}

		// Find chromium directory (version-agnostic)
		const entries = fs.readdirSync(cacheDir)
		const chromiumDir = entries.find((e) => e.startsWith("chromium-"))
		if (!chromiumDir) {
			return { installed: false, chromiumPath: null, chromiumExists: false }
		}

		const chromiumPath = path.join(
			cacheDir,
			chromiumDir,
			"chrome-linux64",
			"chrome",
		)
		const chromiumExists = fs.existsSync(chromiumPath)

		return { installed: true, chromiumPath, chromiumExists }
	} catch {
		return { installed: false, chromiumPath: null, chromiumExists: false }
	}
}

// =============================================================================
// GUIDANCE INJECTION (following metasearch2 plugin pattern)
// =============================================================================

/** Plugin marker for deduplication across config/transform/compacting hooks */
const BROWSER_SAFETY_MARKER = "opencode-browser-safety"

/** Guidance XML injected into the first user message of every turn */
const BROWSER_SAFETY_GUIDANCE = `<BROWSER_SAFETY>
The browser tool (\`browser\`) is provided by opencode-browser-plugin (v1.0.1).
It uses Playwright's \`chromium.launchPersistentContext()\` with a persistent
profile at \`~/.opencode/browser-profile/\`. This profile accumulates stale
state across interrupted sessions and can cause the browser to hang.

**Safety tools** (always available):
- \`browser_health\` — Check Playwright/Chromium installation, profile state,
  and running processes. Call this FIRST before using the browser.
- \`browser_clean\` — Kill zombie Chromium processes and remove stale lock
  files from the browser profile (does NOT require active browser session).
  Pass \`force: true\` to also delete the entire profile directory.

**Pre-launch checklist** (before any \`browser open\` or \`browser_start\`):
1. Call \`browser_health\` to verify installation
2. Clear stale profile: \`rm -rf ~/.opencode/browser-profile/\`
3. Use \`http://127.0.0.1:<port>\` (not \`localhost\`) for local dev servers
4. Pass explicit \`timeout\` (e.g. \`timeout=15000\`)
5. Poll server with \`curl\` before opening

**If ANY browser action hangs** (takes &gt;5s):
1. STOP making further browser calls
2. Run \`browser_clean\` (kills zombies, removes lock files)
3. \`rm -rf ~/.opencode/browser-profile/\` then retry
4. If that also hangs: \`pkill -f "remote-debugging-pipe"\` via bash, then retry
</BROWSER_SAFETY>`

// =============================================================================
// PLUGIN ENTRY
// =============================================================================

const BrowserSafetyPlugin: Plugin = async ({ client }) => {
	return {
		// -------------------------------------------------------------------------
		// Config hook: push marker into instructions
		// -------------------------------------------------------------------------
		config: async (cfg) => {
			cfg.instructions = cfg.instructions ?? []
			const hasMarker = cfg.instructions.some(
				(item) => typeof item === "string" && item.includes(BROWSER_SAFETY_MARKER),
			)
			if (!hasMarker) {
				cfg.instructions.push(
					`${BROWSER_SAFETY_MARKER}: browser_health and browser_clean tools available — use for safe browser automation`,
				)
			}
		},

		// -------------------------------------------------------------------------
		// Messages transform: inject guidance into first user message each turn
		// -------------------------------------------------------------------------
		"experimental.chat.messages.transform": async (_input, output) => {
			if (!output.messages?.length) return

			const firstUser = output.messages.find((m) => m.info?.role === "user")
			if (!firstUser?.parts?.length) return

			const hasTag = firstUser.parts.some(
				(p) =>
					p.type === "text" &&
					typeof p.text === "string" &&
					p.text.includes("<BROWSER_SAFETY>"),
			)
			if (hasTag) return

			firstUser.parts.unshift({
				type: "text",
				text: BROWSER_SAFETY_GUIDANCE,
			} as any)
		},

		// -------------------------------------------------------------------------
		// Session compacting: re-inject guidance so it survives compaction
		// -------------------------------------------------------------------------
		"experimental.session.compacting": async (_input, output) => {
			output.context.push(`
## Browser Safety (${BROWSER_SAFETY_MARKER})
You have \`browser_health\` and \`browser_clean\` tools for safe browser use.
Call \`browser_health\` first to verify browser state.
If browser hangs, run \`browser_clean\` then \`rm -rf ~/.opencode/browser-profile/\`.
`)
		},

		// -------------------------------------------------------------------------
		// Diagnostic tools
		// -------------------------------------------------------------------------
		tool: {
			/**
			 * Clean the browser state - kills zombie processes and removes stale
			 * lock files from the browser profile. Use this when the browser tool
			 * is unresponsive or hanging.
			 */
			browser_clean: tool({
				description: `Clean browser state: kill zombie Chromium processes and remove stale
lock files from the browser profile. Use this when the browser tool is
unresponsive or hanging. Does NOT require an active browser session.

Typical recovery workflow:
  1. Call browser_clean to kill zombie processes and clear locks
  2. Delete the browser profile: rm -rf ~/.opencode/browser-profile/
  3. Start a fresh browser session: browser_open or browser_start`,
				args: {
					force: tool.schema
						.boolean()
						.optional()
						.default(false)
						.describe(
							"If true, also removes the entire browser profile directory",
						),
				},
				async execute(args) {
					const results: string[] = []

					// Kill zombie processes
					const { killed, errors: killErrors } = killZombieChromes()
					results.push(
						`Killed ${killed} orphaned browser process(es)`,
					)
					if (killErrors.length > 0) {
						results.push(`Kill errors: ${killErrors.join("; ")}`)
					}

					// Clean stale lock files
					const { removed, errors: cleanErrors } = cleanBrowserProfile()
					results.push(`Removed ${removed} stale lock file(s)`)
					if (cleanErrors.length > 0) {
						results.push(`Clean errors: ${cleanErrors.join("; ")}`)
					}

					// Force clean: remove entire profile
					if (args.force) {
						try {
							if (fs.existsSync(BROWSER_PROFILE_DIR)) {
								fs.rmSync(BROWSER_PROFILE_DIR, {
									recursive: true,
									force: true,
								})
								results.push("Removed entire browser profile directory")
							} else {
								results.push("No browser profile directory to remove")
							}
						} catch (e: unknown) {
							const msg = e instanceof Error ? e.message : String(e)
							results.push(`Failed to remove profile: ${msg}`)
						}
					}

					return `Browser clean complete:\n  ${results.join("\n  ")}`
				},
			}),

			/**
			 * Check browser health - verify Playwright/Chromium installation
			 * and profile state. Use this to diagnose browser issues.
			 */
			browser_health: tool({
				description: `Check browser health: verify Playwright/Chromium installation,
browser profile state, and running browser processes. Use this to
diagnose browser issues before attempting to use the browser tool.`,
				args: {},
				async execute() {
					const lines: string[] = []

					// Check Playwright browsers
					const pw = checkPlaywrightStatus()
					if (pw.installed) {
						lines.push(
							`Playwright chromium: ${pw.chromiumExists ? "available" : "binary missing"} at ${pw.chromiumPath}`,
						)
					} else {
						lines.push("Playwright chromium: NOT INSTALLED")
					}

					// Check profile directory
					if (fs.existsSync(BROWSER_PROFILE_DIR)) {
						const profileEntries = fs.readdirSync(BROWSER_PROFILE_DIR)
						lines.push(
							`Browser profile: ${profileEntries.length} entries`,
						)

						// Check for stale lock files
						const lockFiles: string[] = []
						const singletonFiles: string[] = []
						for (const entry of profileEntries) {
							if (entry.startsWith("Singleton")) {
								singletonFiles.push(entry)
							}
							if (
								entry.endsWith(".lock") ||
								entry === "LOCK" ||
								entry.startsWith("LOCK-")
							) {
								lockFiles.push(entry)
							}
						}

						if (singletonFiles.length > 0) {
							lines.push(
								`  STALE: ${singletonFiles.length} Singleton file(s) found`,
							)
						}
						if (lockFiles.length > 0) {
							lines.push(
								`  STALE: ${lockFiles.length} lock file(s) found at root`,
							)
						}
					} else {
						lines.push("Browser profile: does not exist")
					}

					// Check for running Chromium processes
					try {
						const result = spawnSync(
							"pgrep",
							[
								"-f",
								// NOTE: pattern MUST NOT start with "--" or pgrep treats it as an option.
								// "remote-debugging-pipe" appears in all Playwright-launched Chromium processes.
								"remote-debugging-pipe|chrome-headless-shell",
							],
							{ encoding: "utf8", timeout: 3000 },
						)
						if (result.status === 0 && result.stdout) {
							const count = result.stdout.trim().split("\n").filter(Boolean)
								.length
							lines.push(
								`Running browser processes: ${count}`,
							)
						} else {
							lines.push("Running browser processes: 0")
						}
					} catch {
						lines.push("Running browser processes: unknown (pgrep not available)")
					}

					return `Browser Health:\n  ${lines.join("\n  ")}`
				},
			}),
		},

		// -------------------------------------------------------------------------
		// Pre-execution hook: clean stale state before browser operations
		// -------------------------------------------------------------------------
		"tool.execute.before": async (input) => {
			if (!input.tool.startsWith("browser")) return

			// For start/open actions, clean stale state proactively
			const action =
				typeof input === "object" && input.tool === "browser"
					? // The browser tool's action is in args.action, but we don't
						// have access to args here - only tool name and session ID.
						// So we clean on ALL browser tool calls for safety.
						"any"
					: input.tool === "browser_start"
						? "start"
						: "other"

			if (action === "start" || action === "any") {
				killZombieChromes()
				cleanBrowserProfile()
			}
		},

		// -------------------------------------------------------------------------
		// Post-execution hook: clean up on failure
		// -------------------------------------------------------------------------
		"tool.execute.after": async (input, output) => {
			if (!input.tool.startsWith("browser")) return

			const result = output.output
			if (typeof result === "string" && result.includes("Error:")) {
				// Browser operation failed - clean up zombie processes
				killZombieChromes()
			}
		},

		// -------------------------------------------------------------------------
		// Session event handler: clean up when sessions end
		// -------------------------------------------------------------------------
		event: async ({ event }) => {
			if (
				event.type === "session.idle" ||
				event.type === "session.deleted"
			) {
				killZombieChromes()
			}
		},
	}
}

/**
 * Expose internals for testing.
 * Follows the same pattern as the worktree plugin.
 */
const BrowserSafetyPluginWithInternals = Object.assign(BrowserSafetyPlugin, {
	testInternals: {
		killZombieChromes,
		cleanBrowserProfile,
		checkPlaywrightStatus,
		removeLockFilesRecursive,
		BROWSER_PROFILE_DIR,
	},
} as const)

export default BrowserSafetyPluginWithInternals
