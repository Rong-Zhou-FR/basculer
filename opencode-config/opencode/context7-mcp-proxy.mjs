#!/usr/bin/env node
/**
 * context7-mcp-proxy.mjs
 *
 * Local-to-remote MCP proxy for Context7.
 * Reads the API key from a file (CONTEXT7_API_KEY_FILE env var) — not from config.
 * This allows the actual key to live in a gitignored file, matching the brave-search pattern.
 *
 * Protocol:
 *   Context7's MCP server uses Streamable HTTP transport with session management.
 *   - First POST request creates a session (returns mcp-session-id header)
 *   - Subsequent requests include MCP-Session-Id header
 *   - Responses are SSE events (text/event-stream)
 *
 * Usage in opencode.jsonc:
 *   {
 *     "type": "local",
 *     "command": ["node", "/home/rongzhou/.config/opencode/context7-mcp-proxy.mjs"],
 *     "environment": {
 *       "CONTEXT7_API_KEY_FILE": "/home/rongzhou/.config/opencode/.secrets/context7-api-key"
 *     }
 *   }
 */

import { readFileSync } from "node:fs";

// ── Configuration ──────────────────────────────────────────────────────

const KEY_FILE = process.env.CONTEXT7_API_KEY_FILE;
if (!KEY_FILE) {
  process.stderr.write("FATAL: CONTEXT7_API_KEY_FILE environment variable not set\n");
  process.exit(1);
}

const API_KEY = readFileSync(KEY_FILE, "utf-8").trim();
if (!API_KEY) {
  process.stderr.write("FATAL: API key file is empty\n");
  process.exit(1);
}

const SERVER_URL = "https://mcp.context7.com/mcp";
const CONTENT_TYPE = "application/json";
const ACCEPT = "application/json, text/event-stream";

// ── Session state ──────────────────────────────────────────────────────

let sessionId = null;

// ── Main loop: read JSON-RPC lines from stdin ──────────────────────────
// Messages are processed sequentially to guarantee session state consistency.

let buffer = "";
const messageQueue = [];
let processing = false;

process.stdin.on("data", (chunk) => {
  buffer += chunk.toString();
  const lines = buffer.split("\n");
  buffer = lines.pop() || ""; // keep incomplete last part

  for (const line of lines) {
    const trimmed = line.trim();
    if (trimmed) {
      messageQueue.push(trimmed);
    }
  }
  dequeue();
});

process.stdin.on("end", () => {
  if (buffer.trim()) {
    messageQueue.push(buffer.trim());
  }
  dequeue();
});

async function dequeue() {
  if (processing) return;
  processing = true;
  while (messageQueue.length > 0) {
    const msg = messageQueue.shift();
    try {
      await handleRequest(msg);
    } catch (err) {
      process.stderr.write(`FATAL: ${err.message}\n`);
    }
  }
  processing = false;
}

// Silence Node's "ExperimentalWarning" for fetch when running standalone
process.on("uncaughtException", (err) => {
  process.stderr.write(`UNCAUGHT: ${err.message}\n`);
});

// ── Core request handler ───────────────────────────────────────────────

async function handleRequest(jsonRpcMessage) {
  // Parse so we can preserve the JSON-RPC id for error responses
  let requestId = null;
  try {
    requestId = JSON.parse(jsonRpcMessage).id ?? null;
  } catch {
    // Malformed input — forward as-is and let the server handle it
  }

  const headers = {
    "Content-Type": CONTENT_TYPE,
    Accept: ACCEPT,
    "CONTEXT7_API_KEY": API_KEY,
  };

  if (sessionId) {
    headers["MCP-Session-Id"] = sessionId;
  }

  let response;
  try {
    response = await fetch(SERVER_URL, {
      method: "POST",
      headers,
      body: jsonRpcMessage,
    });
  } catch (err) {
    process.stderr.write(`ERROR: fetch failed: ${err.message}\n`);
    writeError(requestId, -32000, `Connection failed: ${err.message}`);
    return;
  }

  // Capture session ID from response (first request creates a session)
  const newSessionId = response.headers.get("mcp-session-id");
  if (newSessionId) {
    process.stderr.write(
      `INFO: session established: ${newSessionId.slice(0, 8)}…\n`,
    );
    sessionId = newSessionId;
  }

  if (!response.ok) {
    let body = "";
    try {
      body = await response.text();
    } catch {
      body = "unknown error";
    }
    process.stderr.write(
      `ERROR: HTTP ${response.status}: ${body.slice(0, 200)}\n`,
    );
    writeError(requestId, response.status, body.slice(0, 500));
    return;
  }

  // Read response body (SSE or plain JSON)
  let body;
  try {
    body = await response.text();
  } catch (err) {
    process.stderr.write(`ERROR: reading response body: ${err.message}\n`);
    writeError(requestId, -32000, `Failed to read response: ${err.message}`);
    return;
  }

  if (!body) return; // e.g. notifications with no response body

  // Parse SSE events and extract JSON-RPC data
  const written = writeSseData(body);

  // If no SSE data was found, the response might be plain JSON
  if (!written && body.trim()) {
    process.stdout.write(body + "\n");
  }
}

// ── Helpers ────────────────────────────────────────────────────────────

/**
 * Parse an SSE response body and write each `data:` line to stdout.
 * Returns the number of non-empty data payloads written.
 */
function writeSseData(sseText) {
  let count = 0;

  // SSE events are separated by double newlines
  for (const event of sseText.split("\n\n")) {
    let dataPayload = "";
    let inData = false;

    for (const line of event.split("\n")) {
      if (line.startsWith("data: ")) {
        dataPayload += line.slice(6);
        inData = true;
      } else if (line.startsWith("data:")) {
        // "data:" without trailing space (empty data)
        dataPayload += "";
        inData = true;
      } else if (inData && line.startsWith(" ")) {
        // Multi-line data continuation (SSE spec)
        dataPayload += line.slice(1);
      }
    }

    if (dataPayload) {
      process.stdout.write(dataPayload + "\n");
      count++;
    }
  }

  return count;
}

/**
 * Write a JSON-RPC error response to stdout.
 */
function writeError(id, code, message) {
  const errorResp = JSON.stringify({
    jsonrpc: "2.0",
    id: id ?? null,
    error: { code, message },
  });
  process.stdout.write(errorResp + "\n");
}
