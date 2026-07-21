/**
 * mcp-daemon — Start shared MCP daemons for stateless servers.
 *
 * Stateless MCP servers (brave-search, context7) don't need per-session
 * instances — they serve all sessions equally. This plugin starts them
 * as shared HTTP daemons when opencode starts, and registers cleanup
 * on server shutdown.
 *
 * Why this works: brave-search supports `--transport http` natively.
 * Context7 connects directly to `https://mcp.context7.com/mcp` as a
 * remote server via config (no daemon needed).
 *
 * Per-session servers like serena are NOT started here — they handle
 * per-project state (workspace, LSP) and need their own instance.
 * Those are cleaned by the cron job at ~/.config/opencode/cleanup-mcp.sh
 */
import { type Plugin } from "@opencode-ai/plugin"
import { spawn } from "node:child_process"
import * as net from "node:net"

const DAEMONS: {
	name: string
	port: number
	command: string
	args: string[]
	env?: Record<string, string>
}[] = [
	{
		name: "brave-search",
		port: 8124,
		command: "brave-search-mcp-server",
		args: [
			"--transport", "http",
			"--port", "8124",
			"--host", "127.0.0.1",
		],
		env: {
			BRAVE_API_KEY_FILE: "/home/rongzhou/.config/opencode/.secrets/brave-api-key",
		},
	},
]

/**
 * Check if a TCP port is in use (indicating the daemon is already running).
 */
function portInUse(port: number): Promise<boolean> {
	return new Promise((resolve) => {
		const server = net.createServer()
		server.once("error", () => resolve(true))
		server.once("listening", () => {
			server.close()
			resolve(false)
		})
		server.listen(port, "127.0.0.1")
	})
}

export default (async ({ client }) => {
	const spawnedPids: number[] = []

	for (const daemon of DAEMONS) {
		const alreadyRunning = await portInUse(daemon.port)
		if (alreadyRunning) {
			client.app.log({
				body: {
					service: "mcp-daemon",
					level: "info",
					message: `${daemon.name} already running on port ${daemon.port} — skipping`,
				},
			}).catch(() => {})
			continue
		}

		// Read API key from file for brave-search (like the wrapper does)
		const env: Record<string, string> = { ...daemon.env }
		if (env.BRAVE_API_KEY_FILE) {
			try {
				const { readFileSync } = await import("node:fs")
				const key = readFileSync(env.BRAVE_API_KEY_FILE, "utf-8").trim()
				if (key) {
					env.BRAVE_API_KEY = key
				}
				delete env.BRAVE_API_KEY_FILE
			} catch (err) {
				client.app.log({
					body: {
						service: "mcp-daemon",
						level: "error",
						message: `${daemon.name}: failed to read API key: ${err}`,
					},
				}).catch(() => {})
				continue
			}
		}

		const proc = spawn(daemon.command, daemon.args, {
			env: { ...process.env, ...env },
			stdio: ["ignore", "inherit", "inherit"],
			detached: false,
		})

		spawnedPids.push(proc.pid)

		proc.on("error", (err) => {
			client.app.log({
				body: {
					service: "mcp-daemon",
					level: "error",
					message: `${daemon.name} failed: ${err.message}`,
				},
			}).catch(() => {})
		})

		proc.on("exit", (code, signal) => {
			client.app.log({
				body: {
					service: "mcp-daemon",
					level: "warn",
					message: `${daemon.name} exited (code=${code}, signal=${signal})`,
				},
			}).catch(() => {})
		})

		client.app.log({
			body: {
				service: "mcp-daemon",
				level: "info",
				message: `${daemon.name} started on port ${daemon.port} (PID ${proc.pid})`,
			},
		}).catch(() => {})
	}

	// Cleanup daemons on opencode shutdown
	const cleanup = () => {
		for (const pid of spawnedPids) {
			try {
				process.kill(pid, "SIGTERM")
			} catch {
				// Process might already be dead
			}
		}
	}
	process.on("SIGTERM", cleanup)
	process.on("SIGINT", cleanup)
	process.on("beforeExit", cleanup)

	return {}
}) satisfies Plugin
