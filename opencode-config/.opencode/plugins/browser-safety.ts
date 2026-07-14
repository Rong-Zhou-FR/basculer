/**
 * Browser Safety Plugin
 *
 * Standalone browser automation plugin for opencode with per-session isolation.
 *
 * Each opencode session gets its OWN Chromium process and browser profile
 * directory. Session A cannot interfere with Session B. State is stored in a
 * `Map<sessionID, SessionState>` instead of a single module-level object.
 *
 * Tools: `browser`, `browser_start`, `browser_snapshot`, `browser_click`,
 * `browser_type`, `browser_health`, `browser_clean`.
 *
 * **Safety**: Pre-execution cleanup kills zombie processes and removes stale
 * lock files before browser operations. Guidance injected into every LLM turn
 * via `experimental.chat.messages.transform`.
 *
 * This is a complete replacement for opencode-browser-plugin.
 * Inspired by the original work by heimoshuiyu (opencode-browser-plugin).
 *
 * @module browser-safety
 */

import { type Plugin, tool } from "@opencode-ai/plugin"
import { chromium, type Page, type BrowserContext } from "playwright"
import * as fs from "node:fs"
import * as path from "node:path"
import * as os from "node:os"
import { spawnSync } from "node:child_process"

// =============================================================================
// CONSTANTS
// =============================================================================

/** Root browser profile directory */
const BROWSER_PROFILE_DIR = path.join(os.homedir(), ".opencode", "browser-profile")

/** Per-session profiles live under this subdirectory */
const SESSIONS_PROFILE_DIR = path.join(BROWSER_PROFILE_DIR, "sessions")

/** Timeout for killing browser processes (ms) */
const KILL_TIMEOUT_MS = 5_000

/** Idle timeout before auto-killing a session's browser (30 min) */
const IDLE_TIMEOUT = 30 * 60 * 1_000

/** Idle watchdog check interval */
const IDLE_CHECK_INTERVAL = 60 * 1_000

// =============================================================================
// PER-SESSION STATE
// =============================================================================

interface SessionState {
	context: BrowserContext | null
	pages: Map<string, Page>
	currentPageId: string | null
	pageCounter: number
	refs: Map<string, Map<string, { role: string; name?: string; nth?: number }>>
	headless: boolean
	lastActivityTime: number
}

/**
 * Per-session state map.
 * KEY: opencode session ID (e.g. "ses_0a8744f5affeQOhmyqYcggN6wP")
 * VALUE: browser state for that session only
 */
const sessions = new Map<string, SessionState>()

/** Idle watchdog timer */
let idleCheckInterval: Timer | null = null

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function sanitizeSessionID(id: string): string {
	// Keep only alphanumeric, underscore, hyphen; limit to 12 chars
	return id.replace(/[^a-zA-Z0-9_-]/g, "_").slice(-12)
}

function sessionProfileDir(sessionID: string): string {
	return path.join(SESSIONS_PROFILE_DIR, sanitizeSessionID(sessionID))
}

function getOrCreateSession(sessionID: string): SessionState {
	let s = sessions.get(sessionID)
	if (!s) {
		s = {
			context: null,
			pages: new Map(),
			currentPageId: null,
			pageCounter: 0,
			refs: new Map(),
			headless: true,
			lastActivityTime: 0,
		}
		sessions.set(sessionID, s)
	}
	return s
}

function touchActivity(sessionID: string): void {
	const s = sessions.get(sessionID)
	if (s) s.lastActivityTime = Date.now()
}

function nextPageId(session: SessionState): string {
	session.pageCounter++
	return `page_${session.pageCounter}`
}

function getPage(sessionID: string, pageId: string): Page | undefined {
	return sessions.get(sessionID)?.pages.get(pageId)
}

function getRefs(
	sessionID: string,
): Map<string, { role: string; name?: string; nth?: number }> {
	const s = sessions.get(sessionID)
	if (!s) {
		const m = new Map<string, { role: string; name?: string; nth?: number }>()
		sessions.set(sessionID, { context: null, pages: new Map(), currentPageId: null, pageCounter: 0, refs: new Map(), headless: true, lastActivityTime: 0 })
		sessions.get(sessionID)!.refs.set("default", m)
		return m
	}
	const pageId = s.currentPageId || "default"
	if (!s.refs.has(pageId)) {
		s.refs.set(pageId, new Map())
	}
	return s.refs.get(pageId)!
}

async function getLocatorByRef(
	page: Page,
	sessionID: string,
	ref: string,
) {
	const refs = getRefs(sessionID)
	const info = refs.get(ref)
	if (!info) return null
	const locator = page.getByRole(info.role as any, { name: info.name })
	return info.nth && info.nth > 0 ? locator.nth(info.nth) : locator
}

function resolvePageId(sessionID: string, args: { page_id?: string }): string {
	return args.page_id || sessions.get(sessionID)?.currentPageId || "default"
}

function resolvePage(sessionID: string, pageId: string): Page | string {
	const page = getPage(sessionID, pageId)
	if (!page) return `Error: Page "${pageId}" not found. Open a page first.`
	return page
}

// ---------------------------------------------------------------------------
// Browser lifecycle (per-session)
// ---------------------------------------------------------------------------

interface BrowserResult {
	success: boolean
	error?: string
}

async function ensureBrowser(
	sessionID: string,
	headless = true,
): Promise<BrowserResult> {
	const s = getOrCreateSession(sessionID)
	touchActivity(sessionID)

	if (s.context) {
		// Switching from headless to headed requires restart
		if (!headless && s.headless) {
			await stopBrowser(sessionID)
		} else {
			startIdleWatchdog()
			return { success: true }
		}
	}

	try {
		s.headless = headless
		const profileDir = sessionProfileDir(sessionID)
		if (!fs.existsSync(profileDir)) {
			fs.mkdirSync(profileDir, { recursive: true })
		}

		s.context = await chromium.launchPersistentContext(profileDir, {
			headless,
			viewport: { width: 1280, height: 720 },
		})

		// Register page event handler for new tabs
		s.context.on("page", (page) => {
			const pageId = nextPageId(s)
			s.pages.set(pageId, page)
			s.currentPageId = pageId
			s.refs.set(pageId, new Map())
		})

		startIdleWatchdog()
		return { success: true }
	} catch (error) {
		const errorMessage = error instanceof Error ? error.message : String(error)
		return { success: false, error: errorMessage }
	}
}

async function stopBrowser(sessionID: string): Promise<void> {
	const s = sessions.get(sessionID)
	if (!s) return

	if (s.context) {
		try {
			await s.context.close()
		} catch {
			// Best effort — context may already be closed
		}
	}

	s.context = null
	s.pages.clear()
	s.currentPageId = null
	s.pageCounter = 0
	s.refs.clear()
	s.headless = true
}

function destroySession(sessionID: string): void {
	// Close context (best effort)
	const s = sessions.get(sessionID)
	if (s?.context) {
		s.context.close().catch(() => {})
	}
	sessions.delete(sessionID)

	// Remove session's profile directory
	const profileDir = sessionProfileDir(sessionID)
	if (fs.existsSync(profileDir)) {
		try {
			fs.rmSync(profileDir, { recursive: true, force: true })
		} catch {
			// Best effort
		}
	}
}

// ---------------------------------------------------------------------------
// Idle watchdog
// ---------------------------------------------------------------------------

function startIdleWatchdog(): void {
	if (idleCheckInterval) return

	idleCheckInterval = setInterval(() => {
		const now = Date.now()
		for (const [sid, s] of sessions.entries()) {
			if (!s.context) continue
			const idle = now - s.lastActivityTime
			if (idle >= IDLE_TIMEOUT) {
				stopBrowser(sid).catch(() => {})
				destroySession(sid)
			}
		}

		// Clear interval if no active sessions
		let hasActive = false
		for (const s of sessions.values()) {
			if (s.context) {
				hasActive = true
				break
			}
		}
		if (!hasActive && idleCheckInterval) {
			clearInterval(idleCheckInterval)
			idleCheckInterval = null
		}
	}, IDLE_CHECK_INTERVAL)
}

// ---------------------------------------------------------------------------
// Snapshot builder
// ---------------------------------------------------------------------------

async function buildSnapshot(
	page: Page,
	sessionID: string,
): Promise<{ snapshot: string; refs: string[] }> {
	const snapshot = await page.locator("body").ariaSnapshot()
	const refs = new Map<string, { role: string; name?: string; nth?: number }>()
	const lines = snapshot.split("\n")
	const counter = { value: 0 }
	const roleCounts = new Map<string, number>()

	const processedLines = lines.map((line) => {
		const match = line.match(/^(\s*)-\s*(\w+)(?:\s+"([^"]*)")?/)
		if (!match) return line

		const [, indent, role, name] = match
		const roleKey = `${role}:${name || ""}`
		const count = roleCounts.get(roleKey) || 0
		roleCounts.set(roleKey, count + 1)

		const interactiveRoles = [
			"button", "link", "textbox", "checkbox", "radio", "combobox",
			"listbox", "menuitem", "searchbox", "slider", "switch", "tab",
		]

		if (interactiveRoles.includes(role.toLowerCase())) {
			counter.value++
			const ref = `e${counter.value}`
			refs.set(ref, {
				role: role.toLowerCase(),
				name,
				nth: count > 0 ? count : undefined,
			})

			let processed = `${indent}- ${role}`
			if (name) processed += ` "${name}"`
			processed += ` [ref=${ref}]`
			if (count > 0) processed += ` [nth=${count}]`
			return processed
		}

		return line
	})

	const s = sessions.get(sessionID)
	const pageId = s?.currentPageId || "default"
	if (s) {
		s.refs.set(pageId, refs)
	}

	return {
		snapshot: processedLines.join("\n"),
		refs: Array.from(refs.keys()),
	}
}

// =============================================================================
// UTILITY FUNCTIONS (kill zombies, clean profile, playwright check)
// =============================================================================

/**
 * Kill all orphaned Chromium and Playwright browser processes.
 */
function killZombieChromes(): { killed: number; errors: string[] } {
	const errors: string[] = []
	let killed = 0

	try {
		const result = spawnSync("pgrep", ["-f",
			"remote-debugging-pipe|chrome-headless-shell|chrome-linux64/chrome",
		], { encoding: "utf8", timeout: KILL_TIMEOUT_MS })

		if (result.status === 0 && result.stdout) {
			const pids = result.stdout.trim().split("\n").filter(Boolean)
			for (const pid of pids) {
				try {
					process.kill(parseInt(pid), "SIGTERM")
					killed++
				} catch (e: unknown) {
					const msg = e instanceof Error ? e.message : String(e)
					if (!msg.includes("ESRCH")) errors.push(`SIGTERM ${pid}: ${msg}`)
				}
			}

			if (killed > 0) {
				spawnSync("sleep", ["1"], { timeout: 2000 })
			}

			const result2 = spawnSync("pgrep", ["-f",
				"remote-debugging-pipe|chrome-headless-shell|chrome-linux64/chrome",
			], { encoding: "utf8", timeout: 2000 })

			if (result2.status === 0 && result2.stdout) {
				const remaining = result2.stdout.trim().split("\n").filter(Boolean)
				for (const pid of remaining) {
					try {
						process.kill(parseInt(pid), "SIGKILL")
						killed++
					} catch (e: unknown) {
						const msg = e instanceof Error ? e.message : String(e)
						if (!msg.includes("ESRCH")) errors.push(`SIGKILL ${pid}: ${msg}`)
					}
				}
			}
		}
	} catch (e: unknown) {
		const msg = e instanceof Error ? e.message : String(e)
		if (!msg.includes("exit code 1") && !msg.includes("status 1")) {
			errors.push(`pgrep failed: ${msg}`)
		}
	}

	return { killed, errors }
}

/**
 * Clean the browser profile directory of stale lock files.
 */
function cleanBrowserProfile(
	profileDir?: string,
): { removed: number; errors: string[] } {
	const targetDir = profileDir ?? BROWSER_PROFILE_DIR
	const errors: string[] = []
	let removed = 0

	if (!fs.existsSync(targetDir)) return { removed: 0, errors: [] }

	// Pattern 1: Chromium Singleton* files at root
	try {
		const entries = fs.readdirSync(targetDir)
		for (const entry of entries) {
			if (entry.startsWith("Singleton")) {
				try {
					fs.unlinkSync(path.join(targetDir, entry))
					removed++
				} catch (e: unknown) {
					const msg = e instanceof Error ? e.message : String(e)
					if (!msg.includes("ENOENT")) errors.push(`Failed to remove ${entry}: ${msg}`)
				}
			}
		}
	} catch (e: unknown) {
		const msg = e instanceof Error ? e.message : String(e)
		errors.push(`Failed to read profile directory: ${msg}`)
	}

	// Pattern 2: *.lock / LOCK / LOCK- files recursively in Default/
	const defaultDir = path.join(targetDir, "Default")
	if (fs.existsSync(defaultDir)) {
		try {
			removeLockFilesRecursive(defaultDir, () => { removed++ })
		} catch (e: unknown) {
			const msg = e instanceof Error ? e.message : String(e)
			errors.push(`Failed to clean Default/ locks: ${msg}`)
		}
	}

	return { removed, errors }
}

/**
 * Recursively find and remove lock files.
 */
function removeLockFilesRecursive(dir: string, onRemoved: (name: string) => void): void {
	let entries: string[]
	try {
		entries = fs.readdirSync(dir)
	} catch {
		return
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
			removeLockFilesRecursive(fullPath, onRemoved)
		} else if (entry.endsWith(".lock") || entry === "LOCK" || entry.startsWith("LOCK-")) {
			try {
				fs.unlinkSync(fullPath)
				onRemoved(entry)
			} catch { /* best effort */ }
		}
	}
}

/**
 * Check if Playwright browsers are installed.
 */
function checkPlaywrightStatus(): {
	installed: boolean
	chromiumPath: string | null
	chromiumExists: boolean
} {
	try {
		const cacheDir = path.join(os.homedir(), ".cache", "ms-playwright")
		if (!fs.existsSync(cacheDir)) {
			return { installed: false, chromiumPath: null, chromiumExists: false }
		}
		const entries = fs.readdirSync(cacheDir)
		const chromiumDir = entries.find((e) => e.startsWith("chromium-"))
		if (!chromiumDir) {
			return { installed: false, chromiumPath: null, chromiumExists: false }
		}
		const cp = path.join(cacheDir, chromiumDir, "chrome-linux64", "chrome")
		return { installed: true, chromiumPath: cp, chromiumExists: fs.existsSync(cp) }
	} catch {
		return { installed: false, chromiumPath: null, chromiumExists: false }
	}
}

/** Number of currently tracked sessions (for health reporting) */
function countActiveSessions(): number {
	let count = 0
	for (const s of sessions.values()) {
		if (s.context) count++
	}
	return count
}

/** List session IDs that have active browsers */
function listActiveSessionIDs(): string[] {
	const result: string[] = []
	for (const [sid, s] of sessions.entries()) {
		if (s.context) result.push(sid.slice(-12))
	}
	return result
}

// =============================================================================
// GUIDANCE INJECTION
// =============================================================================

const BROWSER_SAFETY_MARKER = "opencode-browser-safety"

const BROWSER_SAFETY_GUIDANCE = `<BROWSER_SAFETY>
The \`browser\`, \`browser_start\`, \`browser_snapshot\`, \`browser_click\`,
and \`browser_type\` tools are backed by **per-session Chromium isolation**.
Each session gets its OWN browser process and profile directory.
Session A's browser operations never interfere with Session B's.

**Safety tools** (always available):
- \`browser_health\` — Check Playwright/Chromium installation, per-session
  browser state, stale lock files, and running processes.
- \`browser_clean\` — Kill zombie Chromium processes and remove stale lock
  files. Pass \`force: true\` to delete ALL session profiles.

**Pre-launch checklist** (before any \`browser open\` or \`browser_start\`):
1. Call \`browser_health\` first to verify everything is ready
2. Use \`http://127.0.0.1:<port>\` (not \`localhost\`) for local dev servers
3. Pass explicit \`timeout\` (e.g. \`timeout=15000\`)
4. Poll the target server with \`curl\` before opening

**If ANY browser action hangs** (takes &gt;5s):
1. STOP making further browser calls
2. Run \`browser_clean\` (kills zombies, removes lock files)
3. Retry with a fresh \`browser open\` or \`browser_start\`
4. If still fails: \`pkill -f "remote-debugging-pipe"\` via bash, then retry
</BROWSER_SAFETY>`

// =============================================================================
// PLUGIN ENTRY
// =============================================================================

const BrowserSafetyPlugin: Plugin = async ({ client }) => {
	return {
		// -------------------------------------------------------------------------
		// Config hook
		// -------------------------------------------------------------------------
		config: async (cfg) => {
			cfg.instructions = cfg.instructions ?? []
			const hasMarker = cfg.instructions.some(
				(item) => typeof item === "string" && item.includes(BROWSER_SAFETY_MARKER),
			)
			if (!hasMarker) {
				cfg.instructions.push(
					`${BROWSER_SAFETY_MARKER}: per-session browser isolation active — use browser_health and browser_clean for safe browser automation`,
				)
			}
		},

		// -------------------------------------------------------------------------
		// Messages transform: inject guidance into first user message
		// -------------------------------------------------------------------------
		"experimental.chat.messages.transform": async (_input, output) => {
			if (!output.messages?.length) return
			const firstUser = output.messages.find((m) => m.info?.role === "user")
			if (!firstUser?.parts?.length) return
			const hasTag = firstUser.parts.some(
				(p) => p.type === "text" && typeof p.text === "string" && p.text.includes("<BROWSER_SAFETY>"),
			)
			if (hasTag) return
			firstUser.parts.unshift({ type: "text", text: BROWSER_SAFETY_GUIDANCE } as any)
		},

		// -------------------------------------------------------------------------
		// Session compacting: re-inject guidance
		// -------------------------------------------------------------------------
		"experimental.session.compacting": async (_input, output) => {
			output.context.push(`
## Browser Safety (${BROWSER_SAFETY_MARKER})
Per-session browser isolation: each session gets its own Chromium process.
Use \`browser_health\` to check state, \`browser_clean\` to recover from hangs.
`)
		},

		// -------------------------------------------------------------------------
		// TOOLS — standalone browser tools with per-session isolation
		// -------------------------------------------------------------------------
		tool: {
			// =====================================================================
			// browser (main tool with action parameter)
			// =====================================================================
			browser: tool({
				description: `Control a web browser using Playwright. Actions: start, stop, open, navigate, snapshot, screenshot, click, type, evaluate, wait, close, back

Each session gets its own isolated browser process. Session A's browser
never interferes with Session B's browser.

Workflow:
1. start (headed=true for visible window)
2. open url
3. snapshot to get element refs
4. click/type using refs
5. stop when done

Use ref from snapshot for stable element targeting.`,
				args: {
					action: tool.schema.string().describe("Action: start, stop, open, navigate, snapshot, screenshot, click, type, evaluate, wait, close, back"),
					url: tool.schema.string().optional().describe("URL to open or navigate to"),
					page_id: tool.schema.string().optional().default("default").describe("Page/tab identifier (default: 'default')"),
					ref: tool.schema.string().optional().describe("Element ref from snapshot (preferred over selector)"),
					selector: tool.schema.string().optional().describe("CSS selector (use ref when possible)"),
					text: tool.schema.string().optional().describe("Text to type"),
					code: tool.schema.string().optional().describe("JavaScript code to evaluate"),
					path: tool.schema.string().optional().describe("File path for screenshot"),
					wait: tool.schema.number().optional().default(0).describe("Milliseconds to wait"),
					full_page: tool.schema.boolean().optional().default(false).describe("Full page screenshot"),
					headed: tool.schema.boolean().optional().default(false).describe("Show visible browser window"),
					submit: tool.schema.boolean().optional().default(false).describe("Press Enter after typing"),
					slowly: tool.schema.boolean().optional().default(false).describe("Type character by character"),
					timeout: tool.schema.number().optional().default(30000).describe("Timeout in milliseconds"),
				},
				async execute(args, context) {
					const sessionID = context.sessionID
					const action = args.action.toLowerCase().trim()

					try {
						touchActivity(sessionID)

						if (action === "start") {
							const headless = !(args.headed ?? false)
							const result = await ensureBrowser(sessionID, headless)
							if (!result.success) {
								return `Failed to start browser: ${result.error}. Make sure Playwright is installed: bunx playwright install chromium`
							}
							return `Browser started (${args.headed ? "visible window" : "headless"}) [session: ${sessionID.slice(-8)}]`
						}

						if (action === "stop") {
							await stopBrowser(sessionID)
							return "Browser stopped"
						}

						if (action === "open") {
							if (!args.url) return "Error: url required for open action"
							const result = await ensureBrowser(sessionID)
							if (!result.success) {
								return `Error: Failed to start browser: ${result.error}`
							}
							const s = sessions.get(sessionID)
							if (!s?.context) return "Error: No browser context"
							const pageId = args.page_id || nextPageId(s)
							const page = await s.context.newPage()
							s.pages.set(pageId, page)
							s.currentPageId = pageId
							s.refs.set(pageId, new Map())
							await page.goto(args.url, { timeout: args.timeout })
							return `Opened ${args.url} (page_id: ${pageId})`
						}

						if (action === "navigate") {
							if (!args.url) return "Error: url required for navigate action"
							const pageId = resolvePageId(sessionID, args)
							const page = resolvePage(sessionID, pageId)
							if (typeof page === "string") return page
							await page.goto(args.url, { timeout: args.timeout })
							return `Navigated to ${args.url}`
						}

						if (action === "back") {
							const pageId = resolvePageId(sessionID, args)
							const page = resolvePage(sessionID, pageId)
							if (typeof page === "string") return page
							await page.goBack({ timeout: args.timeout })
							return "Navigated back"
						}

						if (action === "snapshot") {
							const pageId = resolvePageId(sessionID, args)
							const page = resolvePage(sessionID, pageId)
							if (typeof page === "string") return page
							const result = await buildSnapshot(page, sessionID)
							let output = `Page: ${page.url()}\n\n`
							output += `Interactive Elements:\n${result.snapshot}\n\n`
							output += `Available refs: ${result.refs.join(", ")}`
							if (args.path) {
								const filePath = path.isAbsolute(args.path)
									? args.path
									: path.join(context.directory, args.path)
								await fs.promises.writeFile(filePath, output, "utf-8")
								output += `\n\nSnapshot saved to: ${args.path}`
							}
							return output
						}

						if (action === "screenshot") {
							const pageId = resolvePageId(sessionID, args)
							const page = resolvePage(sessionID, pageId)
							if (typeof page === "string") return page
							const screenshotPath = args.path || `screenshot-${Date.now()}.png`
							const filePath = path.isAbsolute(screenshotPath)
								? screenshotPath
								: path.join(context.directory, screenshotPath)
							if (args.ref) {
								const locator = await getLocatorByRef(page, sessionID, args.ref)
								if (!locator) return `Error: Ref '${args.ref}' not found`
								await locator.screenshot({ path: filePath })
							} else {
								await page.screenshot({ path: filePath, fullPage: args.full_page })
							}
							return `Screenshot saved to ${screenshotPath}`
						}

						if (action === "click") {
							const pageId = resolvePageId(sessionID, args)
							const page = resolvePage(sessionID, pageId)
							if (typeof page === "string") return page
							if (!args.ref && !args.selector) return "Error: ref or selector required for click"
							const locator = args.ref
								? await getLocatorByRef(page, sessionID, args.ref)
								: page.locator(args.selector!).first()
							if (!locator) return `Error: Ref '${args.ref}' not found`
							await locator.click({ timeout: args.timeout })
							if (args.wait && args.wait > 0) await page.waitForTimeout(args.wait)
							return `Clicked ${args.ref || args.selector}`
						}

						if (action === "type") {
							const pageId = resolvePageId(sessionID, args)
							const page = resolvePage(sessionID, pageId)
							if (typeof page === "string") return page
							if (!args.ref && !args.selector) return "Error: ref or selector required for type"
							if (!args.text) return "Error: text required for type action"
							const locator = args.ref
								? await getLocatorByRef(page, sessionID, args.ref)
								: page.locator(args.selector!).first()
							if (!locator) return `Error: Ref '${args.ref}' not found`
							if (args.slowly) {
								await locator.pressSequentially(args.text)
							} else {
								await locator.fill(args.text)
							}
							if (args.submit) await locator.press("Enter")
							return `Typed into ${args.ref || args.selector}`
						}

						if (action === "evaluate" || action === "eval") {
							const pageId = resolvePageId(sessionID, args)
							const page = resolvePage(sessionID, pageId)
							if (typeof page === "string") return page
							if (!args.code) return "Error: code required for evaluate"
							const result = await page.evaluate(args.code)
							return `Result: ${JSON.stringify(result, null, 2)}`
						}

						if (action === "wait") {
							const pageId = resolvePageId(sessionID, args)
							const page = resolvePage(sessionID, pageId)
							if (typeof page === "string") return page
							if (args.wait && args.wait > 0) {
								await page.waitForTimeout(args.wait)
								return `Waited ${args.wait}ms`
							}
							await page.waitForLoadState("networkidle", { timeout: args.timeout })
							return "Waited for network idle"
						}

						if (action === "close") {
							const s = sessions.get(sessionID)
							const pageId = args.page_id || s?.currentPageId
							if (!pageId) return "Error: No page to close"
							const page = getPage(sessionID, pageId)
							if (!page) return "Error: Page not found"
							await page.close()
							if (s) {
								s.pages.delete(pageId)
								s.refs.delete(pageId)
								if (s.currentPageId === pageId) {
									s.currentPageId = s.pages.keys().next().value || null
								}
							}
							return `Closed page ${pageId}`
						}

						return `Error: Unknown action '${action}'. Available: start, stop, open, navigate, back, snapshot, screenshot, click, type, evaluate, wait, close`
					} catch (error) {
						const errorMessage = error instanceof Error ? error.message : String(error)
						return `Error: ${errorMessage}`
					}
				},
			}),

			// =====================================================================
			// browser_start (headed mode)
			// =====================================================================
			browser_start: tool({
				description: "Start browser in visible mode (headed) for debugging or demos",
				args: {
					headed: tool.schema.boolean().default(true).describe("Show visible browser window"),
				},
				async execute(args, context) {
					const sessionID = context.sessionID
					const headless = !args.headed
					const result = await ensureBrowser(sessionID, headless)
					return result.success
						? `Browser started in ${args.headed ? "visible" : "headless"} mode`
						: `Failed to start browser: ${result.error}`
				},
			}),

			// =====================================================================
			// browser_snapshot
			// =====================================================================
			browser_snapshot: tool({
				description: "Take a snapshot of the current page to get interactive element refs",
				args: {
					page_id: tool.schema.string().optional().describe("Page ID (optional)"),
				},
				async execute(args, context) {
					const sessionID = context.sessionID
					const s = sessions.get(sessionID)
					const pageId = args.page_id || s?.currentPageId || "default"
					const page = getPage(sessionID, pageId)
					if (!page) return "Error: Page not found. Open a page first."
					const result = await buildSnapshot(page, sessionID)
					return `Page: ${page.url()}\n\n${result.snapshot}\n\nRefs: ${result.refs.join(", ")}`
				},
			}),

			// =====================================================================
			// browser_click
			// =====================================================================
			browser_click: tool({
				description: "Click an element using ref from snapshot",
				args: {
					ref: tool.schema.string().describe("Element ref from snapshot"),
					page_id: tool.schema.string().optional().describe("Page ID (optional)"),
				},
				async execute(args, context) {
					const sessionID = context.sessionID
					const s = sessions.get(sessionID)
					const pageId = args.page_id || s?.currentPageId || "default"
					const page = getPage(sessionID, pageId)
					if (!page) return "Error: Page not found"
					const locator = await getLocatorByRef(page, sessionID, args.ref)
					if (!locator) return `Error: Ref '${args.ref}' not found`
					await locator.click()
					return `Clicked ${args.ref}`
				},
			}),

			// =====================================================================
			// browser_type
			// =====================================================================
			browser_type: tool({
				description: "Type text into an element using ref from snapshot",
				args: {
					ref: tool.schema.string().describe("Element ref from snapshot"),
					text: tool.schema.string().describe("Text to type"),
					submit: tool.schema.boolean().optional().default(false).describe("Press Enter after typing"),
					page_id: tool.schema.string().optional().describe("Page ID (optional)"),
				},
				async execute(args, context) {
					const sessionID = context.sessionID
					const s = sessions.get(sessionID)
					const pageId = args.page_id || s?.currentPageId || "default"
					const page = getPage(sessionID, pageId)
					if (!page) return "Error: Page not found"
					const locator = await getLocatorByRef(page, sessionID, args.ref)
					if (!locator) return `Error: Ref '${args.ref}' not found`
					await locator.fill(args.text)
					if (args.submit) await locator.press("Enter")
					return `Typed into ${args.ref}`
				},
			}),

			// =====================================================================
			// browser_clean
			// =====================================================================
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
						.describe("If true, also removes the entire browser profile directory and all session profiles"),
				},
				async execute(args) {
					const results: string[] = []

					// Kill zombie processes
					const { killed, errors: killErrors } = killZombieChromes()
					results.push(`Killed ${killed} orphaned browser process(es)`)
					if (killErrors.length > 0) {
						results.push(`Kill errors: ${killErrors.join("; ")}`)
					}

					// Clean stale lock files from root profile
					const { removed, errors: cleanErrors } = cleanBrowserProfile()
					results.push(`Removed ${removed} stale lock file(s)`)
					if (cleanErrors.length > 0) {
						results.push(`Clean errors: ${cleanErrors.join("; ")}`)
					}

					// Force clean: destroy ALL session profiles and state
					if (args.force) {
						// Kill each session's browser
						for (const [sid, s] of sessions.entries()) {
							if (s.context) {
								try { await s.context.close() } catch { /* best effort */ }
							}
						}
						sessions.clear()

						// Remove all session profile directories
						if (fs.existsSync(SESSIONS_PROFILE_DIR)) {
							try {
								fs.rmSync(SESSIONS_PROFILE_DIR, { recursive: true, force: true })
								results.push("Removed all session profile directories")
							} catch (e: unknown) {
								const msg = e instanceof Error ? e.message : String(e)
								results.push(`Failed to remove session profiles: ${msg}`)
							}
						}

						// Also remove root profile
						if (fs.existsSync(BROWSER_PROFILE_DIR)) {
							try {
								fs.rmSync(BROWSER_PROFILE_DIR, { recursive: true, force: true })
								results.push("Removed entire browser profile directory")
							} catch (e: unknown) {
								const msg = e instanceof Error ? e.message : String(e)
								results.push(`Failed to remove profile: ${msg}`)
							}
						}
					}

					return `Browser clean complete:\n  ${results.join("\n  ")}`
				},
			}),

			// =====================================================================
			// browser_health
			// =====================================================================
			browser_health: tool({
				description: `Check browser health: verify Playwright/Chromium installation,
browser profile state, and running browser processes. Use this to
diagnose browser issues before attempting to use the browser tool.`,
				args: {},
				async execute() {
					const lines: string[] = []

					// Playwright status
					const pw = checkPlaywrightStatus()
					if (pw.installed) {
						lines.push(`Playwright chromium: ${pw.chromiumExists ? "available" : "binary missing"} at ${pw.chromiumPath}`)
					} else {
						lines.push("Playwright chromium: NOT INSTALLED")
					}

					// Session info
					const activeSessions = countActiveSessions()
					const activeIDs = listActiveSessionIDs()
					lines.push(`Active browser sessions: ${activeSessions}`)
					if (activeIDs.length > 0) {
						lines.push(`  Session IDs: ${activeIDs.join(", ")}`)
					}

					// Profile directories
					if (fs.existsSync(SESSIONS_PROFILE_DIR)) {
						const sessionDirs = fs.readdirSync(SESSIONS_PROFILE_DIR)
						lines.push(`Session profile directories: ${sessionDirs.length}`)
					} else {
						lines.push("Session profile directories: none")
					}

					// Running Chromium processes
					try {
						const result = spawnSync("pgrep", ["-f", "remote-debugging-pipe|chrome-headless-shell"],
							{ encoding: "utf8", timeout: 3000 })
						if (result.status === 0 && result.stdout) {
							const count = result.stdout.trim().split("\n").filter(Boolean).length
							lines.push(`Running browser processes: ${count}`)
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
		// Pre-execution hook: per-session cleanup before browser operations
		// -------------------------------------------------------------------------
		"tool.execute.before": async (input) => {
			if (!input.tool.startsWith("browser")) return
			// Clean stale lock files from this session's profile if it exists
			if (input.sessionID) {
				const s = sessions.get(input.sessionID)
				if (s?.context) {
					// Context is alive — just touch activity time
					touchActivity(input.sessionID)
				} else {
					// No active context — clean up stale profile
					const profileDir = sessionProfileDir(input.sessionID)
					if (fs.existsSync(profileDir)) {
						cleanBrowserProfile(profileDir)
					}
				}
			}
			// Global cleanup: kill orphaned processes
			killZombieChromes()
		},

		// -------------------------------------------------------------------------
		// Post-execution hook: clean up on failure
		// -------------------------------------------------------------------------
		"tool.execute.after": async (input) => {
			if (!input.tool.startsWith("browser")) return
			if (input.sessionID) {
				touchActivity(input.sessionID)
			}
		},

		// -------------------------------------------------------------------------
		// Session event handler: destroy per-session browser when session ends
		// -------------------------------------------------------------------------
		event: async ({ event }) => {
			if (event.type === "session.idle" || event.type === "session.deleted") {
				// Destroy browser for this specific session
				const sessionID = (event as any).sessionID
				if (sessionID && sessions.has(sessionID)) {
					await stopBrowser(sessionID)
					destroySession(sessionID)
				}
				// Also kill any remaining orphaned processes
				killZombieChromes()
			}
		},
	}
}

// =============================================================================
// Test internals export
// =============================================================================

const BrowserSafetyPluginWithInternals = Object.assign(BrowserSafetyPlugin, {
	testInternals: {
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
	},
} as const)

export default BrowserSafetyPluginWithInternals
