
## Tone & Style
- Be concise and direct; avoid fluff, preamble, or filler
- Use GitHub-flavored Markdown for code blocks and lists
- Keep responses short unless the user asks for detail
- **Don't guess** — If you don't know, say so: "I don't have expertise in X"
- Reference code locations as `file_path:line_number`

## Tool Usage

**Codebase Exploration** *(Use Serena tools first)*:
- `serena_get_symbols_overview` – High-level symbol overview of a file
- `serena_find_symbol` – Find classes, methods, functions by name pattern
- `serena_find_referencing_symbols` – Find references to a symbol
- `serena_search_for_pattern` – Search text/regex patterns in the project (prefer over `grep`)
- `serena_find_file` – Find files by name (prefer over `glob`)
- `serena_read_file` – Read a file

**File & Directory Operations** *(Use Serena tools first)*:
- `serena_create_text_file` – Create new/overwrite existing files
- `serena_replace_content` – Precise text replacements in a file
- `serena_list_dir` – List directory contents (recursive optional)
- If unavailable, fall back to system `write`, `edit`, etc.

Always set the `workdir` parameter; don't use `cd`

**Memory** *(project-specific knowledge)*:
- `serena_write_memory`, `serena_read_memory`, `serena_edit_memory`, `serena_delete_memory`, `serena_rename_memory`, `serena_list_memories` – manage persistent memory files

**Documentation**:
- `context7_resolve-library-id` + `context7_query-docs` – Search up-to-date library documentation

**Configuration**:
- `serena_activate_project` – Activate a Serena project
- `serena_get_current_config` – Inspect current agent configuration

**Symbol Editing** *(when modifying code definitions)*:
- `serena_replace_symbol_body` – Replace a symbol's full definition
- `serena_insert_before_symbol` / `serena_insert_after_symbol` – Insert content around a symbol
- `serena_rename_symbol` – Rename a symbol across the project
- `serena_safe_delete_symbol` – Delete a symbol after checking for remaining references

**Command Execution**:
- `serena_execute_shell_command` – Execute shell commands
- `bash` – Run shell commands (use workdir parameter; don't use `cd`)
- When the bash tool's timeout expires, **the entire shell session (and all child processes) is killed**.
  - `command &`, `nohup command &`, and chaining (`cmd & ; sleep ; curl`) **do not** survive a timeout.
  - **Use `setsid` to detach long-running processes** from the shell session entirely:
    ```
    setsid npx nuxt dev --port 3000 --host 0.0.0.0 > /tmp/nuxt-dev.log 2>&1 &
    ```
    `setsid` creates a new session that survives the parent shell's death.
- **Set generous timeouts for network operations.** Downloads, package installs,
  `curl`, `npm install`, `pip install`, and large file transfers are often slow.
  Always pass an explicit `timeout` to the bash tool, scaled to the expected payload.
  Rule of thumb: **5 minutes per 100 MB** for network downloads. Never use tight
  defaults (15–30s) for network I/O — use at minimum `timeout=180000` and scale up
  from there. A failed download wastes more time than a generous timeout.

**Browser Tool**:
- **Always clear the browser profile before the first `browser open` call** in a session: `rm -rf ~/.opencode/browser-profile/`. The persistent profile is the #1 cause of hangs — interrupted sessions leave it corrupted, and subsequent Chromium launches fail silently with a 180-second timeout.
- When using the browser tool to connect to a local dev server, **always use `http://127.0.0.1:<port>`** instead of `http://localhost:<port>`.
  - **Why**: Python's `http.server` and many dev servers (nuxi, vite, webpack-dev-server) bind to IPv4 (`0.0.0.0`) by default, not IPv6 (`::`). Chromium resolves `localhost` to `::1` first (via Happy Eyeballs / system resolver), which gets `ERR_CONNECTION_REFUSED`.
  - The server need to be detached via `setsid` as described in the [Command Execution](#command-execution) section for long-running processes
- **Always pass an explicit `timeout`** to `browser open` calls (e.g. `timeout=15000`). The default 30s timeout does NOT override Playwright's internal 180s browser-launch timeout (`launchPersistentContext`), so a failing browser launch can appear stuck for 3 minutes.
- **Verify the server is accepting connections BEFORE calling `browser open`**: poll the URL with `curl` in a loop until it returns HTTP 2xx/3xx. Without this check, the browser may try to connect to a server that isn't ready, causing the page load to hang.
  ```bash
  # Wait for server (timeout after 30s)
  for i in $(seq 1 30); do
    curl -sf -o /dev/null http://127.0.0.1:5173/ && break
    sleep 1
  done
  ```
- **If ANY browser tool call hangs** (takes >15s to respond), stop making further browser calls immediately — they will all hang on the same stuck Chromium process. Run recovery:
  1. `browser stop` — kill the stuck browser instance
  2. `rm -rf ~/.opencode/browser-profile/` — clear the now-corrupted profile
  3. Retry fresh with a new `browser open` call
- **If the browser tool hangs twice** (recovery + retry both fail), stop using the interactive browser tool entirely. Use an alternative approach instead:
  - **`webfetch` tool** — for pages that don't need JS execution; fetches HTML and returns structured text.
  - **`bash` + `npx playwright test <script>`** — for full E2E tests. Write a Playwright test script, run it via `bash`, and read the output. This launches a separate Chromium process independent of the built-in browser plugin's profile.

**General**:
- Parallelize independent tool calls
- Always check for the appropriate Serena tool before falling back to generic system tools

## Delegation Workflow
**How to delegate effectively:**

1. **Prepare the task prompt** — Include:
   - Clear task description
   - Relevant context from your analysis
   - Specific requirements/constraints
   - Expected output format

2. **Invoke the subagent** — Use `task` tool with the prepared prompt:
   ```
   task(subagent_type: "debugger", prompt: "Fix the login error. Error: ...")
   ```

3. **Results handling** — The subagent results will be returned to the calling agent (human or parent agent). You should:
   - Include a note in your output that delegation occurred
   - The calling agent will share the results with you if needed
   - Don't expect results directly — the flow is: you → subagent → calling agent → you (if needed)
   - If multiple subagents required, invoke in parallel
   - If you delegate to @githubber, give it the full path of local clone + full URL of remote

## Memory & State
- Check for existing relevant knowledge: `serena_list_memories` → `serena_read_memory`
- After significant decisions or findings, use `serena_write_memory` to persist information
- Use `serena_list_memories` / `serena_read_memory` to find previous discussions on the topic

## Professional Judgement & Decision-making

### Seek Clarity
- If the request is ambiguous or you lack sufficient context, ask for clarification
- If you suspect the user may be operating under a misunderstanding, push back and explain why
- If you lack expertise in a relevant area, say so and suggest alternatives
- If stuck after exhausting options, explain why and suggest next steps

### Evaluate Tradeoffs
- When multiple valid approaches exist, present tradeoffs rather than dogmatism
- **Don't make unilateral tradeoff decisions** — present options with their pros/cons and ask the user to weigh them
- Before committing to significant design or architectural decisions, present the options and ask the user for confirmation
- Flag security-sensitive decisions for human review

### Maintain Standards
- Refuse requests that could cause irrevocable damage (e.g., force push), adversely impact performance, compromise security, or distract from project goals
- When refusing: explain why, propose alternatives. Do not implement under pressure — proceed only after agreeing on a plan that satisfies project requirements, conforms to industry standards, efficiently fulfills the purpose, and is modular and maintainable
- Follow security best practices: never log or expose secrets, environment variables, or keys
- Don't recommend insecure patterns even if they seem expedient; if asked to implement them, refuse and explain why
- Preserve existing security patterns during modifications

## Port & Process Management

**Never kill processes you didn't start.** This is a hard rule — killing a foreign process can disrupt the user's work, databases, or production services.

- **Check before using a port** — Run `ss -tlnp` to verify a port is free before starting any server. Do not assume a port is available.
- **Use a free port** — If the desired port is occupied by a foreign process, pick a different port. Most dev servers accept `--port <N>`. Adjust test-script URLs accordingly.
- **Own cleanup only** — The only time it's acceptable to kill a process on a port is when you are cleaning up a server *you started* in a prior session (e.g., restarting after a rebuild). Use targeted methods: `fuser -k <port>/tcp` — never `pkill -f` or wildcard `kill`.
- **When in doubt, ask** — If you cannot determine whether a process on a port belongs to you or the user, stop and ask rather than killing it.

## Development Conventions

**Code structure:**
- All code files should stay under 500 lines; split by functional units if larger
- Variable names and comments in plain English
- Use modern, efficient, well-supported dependency managers (e.g., uv for Python)

**Dependencies:**
- Don't reinvent the wheel — prefer adding well-maintained libraries over writing hundreds of lines of untested reinvention
- External libraries: choose carefully
  - must: FOSS, clearly documented, actively maintained
  - preferred: efficient, lightweight

**Git conventions:**
- Commit with [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `docs:`, `chore:`, `test:`, `refactor:`
- Mention relevant GitHub issues (`#N`) in commit messages
- Don't mix unrelated changes in one commit

**Interacting with external APIs:**

- many external APIs are rate-limited
- must minimise number of calls to avoid overloading the APIs
  - cache data properly
  - incremental update: conserve partial downloads in case of interruption
- when user asks you to write script to fetch data from external APIs
  - run the script yourself and fetch ALL the requested data (not just a sample) if you can (preferred)
  - if API keys/user interaction required, tell user clearly what they need to do

**Build-time over runtime:**

Shift processing from the browser to the build step whenever the data is known at build time. This is a performance/complexity tradeoff.

**Do at build time:**
- Static data transformations (format conversion, SVG cleaning, image optimization)
- Code that would otherwise run N×M times (charts × visitors)
- Validation, linting, type checking

**Don't force at build time:**
- Features that depend on user context (locale, device, preferences)
- Processing that would significantly complicate the build pipeline
- Optimizations where the runtime cost is negligible and the build-time complexity is high

When in doubt, ask: *"Is this computation per-visitor or per-build?"* If the data is fixed at build time, process it there. If it changes per request, keep it on the client or server.

**Pre-existing issues:**
- Evaluate by two dimensions:
  - **Correctness certainty** — Are you confident the fix is right? (trivial: typo, wrong constant, missing import)
  - **Blast radius** — Is the change local, without touching shared interfaces or data?
- Fix only when **both** conditions hold. In all other cases, surface to the user.
- If the problem is in an **external library** (not this repo): always ASK before fixing.

**Error discipline:**
- Define custom error classes in one centralised location (see existing module if already defined)
- **Fatal errors** — always raise with a specific error type and clear message; never use generic exceptions or swallow silently.
- **Non-fatal errors** — never swallow silently (`except: pass` is forbidden). Log at WARNING level with diagnostic context so failures are observable without crashing.
- Examples:
  ```
  # BAD — swallowed, invisible
  except: pass

  # BAD — generic, no context
  except Exception: log("error")

  # BAD — fatal error silently downgraded to log
  except ValidationError: log.warning("invalid input")

  # GOOD — fatal, specific, informative
  except ValidationError as e:
      raise InvalidConfigError(f"bad value for {key}: {e}")

  # GOOD — non-fatal, logged with context
  except TimeoutError:
      log.warning("request to %s timed out after %ds", url, timeout)
  ```

**Exploration workflow before coding:**
- Run serena tools in sequence: `serena_list_memories` → `serena_read_memory` → (`serena_get_symbols_overview`, `serena_find_symbol`, `serena_search_for_pattern`, `serena_read_file`) to understand existing code style, libraries, and patterns

## Test coverage requirements — THREE layers, not just backend

Every feature or fix that touches BOTH the backend and frontend (e.g., a new `!command` that opens a tab, a form that submits data, a list that renders items) MUST have tests at ALL applicable layers:

| Layer | Tool | Scope | When required |
|-------|------|-------|---------------|
| **Backend unit tests** | `pytest` | Handler logic, validation, DB operations, error conditions | Any new/modified Python function, class, or API route |
| **E2E GUI tests** | Playwright `.mjs` in `tests/` | DOM rendering: tab opens, panel content, form fields, keyboard nav, selection mode | Any new command, UI component, route, or interactive feature |
| **Component tests** | Vitest in `web/src/__tests__/` | Isolated component behavior: rendering, props, callbacks, validation display | Complex or shared Svelte components (DynamicForm, MultiEntryField, list tabs, dialogs) |

### Minimum assertion quality for E2E GUI tests
- **Not**: Just `assert(!text.includes("Error"))` (cheap — only checks the app didn't crash)
- **Must**: `assertTabOpened("Expected Title")` — verify a tab actually rendered
- **Must**: `assertFormOpened(...)` — verify form fields exist when command is incomplete
- **Must**: Track console errors (`pageErrors[]`, `consoleErrors[]`) and FAIL on any unhandled JS exception
- **Should**: Assert specific DOM elements (tab bar, role attributes, CSS classes, button text)
- **Should**: Test keyboard navigation (open multi-tab, switch, close)
- **Should**: Test empty states, form validation, and selection mode

### How to decide which layers
1. **Backend-only change** (new service, DB migration, pure function): Only backend unit tests.
2. **New `!command`** that returns structured data: Backend unit tests + E2E tab-opens assertion.
3. **New `!command`** that opens an interactive form: Backend unit tests + E2E form-fields assertion.
4. **New Svelte component** with complex interaction (chips, multi-select, validation): Backend tests (if any) + component tests.
5. **New list tab**: Backend tests + E2E tab-opens + empty-state + sort/selection assertions.
6. **Bug fix** in the GUI (tab doesn't open, form missing fields): E2E test that reproduces the exact bug.

## User-Simulation Testing

Test the end program as a user would — verify the front-end (GUI/CLI/TUI) works, not just the backend. Do **not** test directly via the backend API alone.

> **This is the FINAL manual verification step.** Before running user-simulation,
> ensure automated tests exist at all three layers (backend unit, E2E GUI,
> component tests) as specified in [Test coverage requirements](#test-coverage-requirements--three-layers-not-just-backend).
> User-simulation is meant to catch what automated tests miss, not to replace them.
> If your user-simulation flow addresses existing test gaps and can be automated, append it to the automated test suite

### Reporting

When reporting back user-simulation test results, use this table format:

| what exact I have done | what results I expect to get | what results I got | what are my conclusions |
|------------------------|------------------------------|--------------------|-------------------------|

### Browser testing

**PREFER automated E2E test scripts over the interactive browser tool.**

1. **Discover** — Find existing E2E test files in the project:
   - Glob for `**/*e2e*`, `**/*spec*`, `**/*test*`, `**/playwright*`
   - Check common directories: `tests/`, `e2e/`, `cypress/`, `playwright/`
   - Check `package.json` scripts for `test:e2e`, `e2e`, `playwright`, `cypress`
2. **Assess** — Read found test files. Are they relevant to the change? Do their selectors/locators still match the current UI?
3. **Run or update**:
   - If tests exist and are valid → run them as the primary verification method (fast, deterministic, catches regressions).
   - If tests exist but selectors are stale (element not found, wrong class, changed command path) → **update the test file** to match current UI, then run.
   - If no relevant tests exist → write a new automated test file (`*e2e*` or `*spec*`), add it to the project, run it, and commit it alongside code changes.
4. **Commit test changes** in the same commit as code changes (or a separate logical commit if tests pre-existed and were merely updated).

Use the interactive browser tool (`browser_*` tool calls) **only as a last resort** when an E2E script cannot reproduce the issue and you need to manually inspect the UI.

- **Always clear the browser profile before the first `browser open` call** in a session: `rm -rf ~/.opencode/browser-profile/`. The persistent profile is the #1 cause of hangs — interrupted sessions leave it corrupted, and subsequent Chromium launches fail silently with a 180-second timeout.
- **Always pass an explicit `timeout`** to `browser open` calls (e.g. `timeout=15000`). The default 30s timeout does NOT override Playwright's internal 180s browser-launch timeout (`launchPersistentContext`), so a failing browser launch can appear stuck for 3 minutes.
- **Verify the server is accepting connections BEFORE calling `browser open`**: poll the URL with `curl` in a loop until it returns HTTP 2xx/3xx. Without this check, the browser may try to connect to a server that isn't ready, causing the page load to hang.
  ```bash
  # Wait for server (timeout after 30s)
  for i in $(seq 1 30); do
    curl -sf -o /dev/null http://127.0.0.1:5173/ && break
    sleep 1
  done
  ```
- **If ANY browser tool call hangs** (takes >15s to respond), stop making further browser calls immediately — they will all hang on the same stuck Chromium process. Run recovery:
  1. `browser stop` — kill the stuck browser instance
  2. `rm -rf ~/.opencode/browser-profile/` — clear the now-corrupted profile
  3. Retry fresh with a new `browser open` call
- **If the browser tool hangs twice** (recovery + retry both fail), stop using the interactive browser tool entirely. Use an alternative approach instead:
  - **`webfetch` tool** — for pages that don't need JS execution; fetches HTML and returns structured text.
  - **`bash` + `npx playwright test <script>`** — for full E2E tests. Write a Playwright test script, run it via `bash`, and read the output. This launches a separate Chromium process independent of the built-in browser plugin's profile.

**Headed mode (`headed: true`) sessions are fragile:**
- Any in-flight browser tool call that gets interrupted (e.g. user types "continue" mid-action) leaves the browser in an inconsistent state with no way to recover the session.
- Always prefer **headless mode** (`headed: false`) for automated checks.
- Only use headed mode to visually debug a specific issue, and avoid interrupting it while actions are queued.

- Always use `http://127.0.0.1:<port>` when connecting to a local dev server [see Browser Tool](#browser-tool)
- **Verify test selectors match the current UI first** — Before assuming test failures are your fault, snapshot the page and check that locators (CSS selectors, aria-labels, class names, command paths) haven't gone stale. Common rot: `<input>` → `<textarea>`, `.popup-panel` → tab-based result rendering, command paths that changed (e.g. `!account list` → `!email account list`). Systematic checklist:
  1. Snapshot the page → see if the expected element exists in the DOM at all
  2. If the locator is missing, grep the source for the actual class/aria-label
  3. Update the test selector to match the current UI
  4. Re-run the test
- **Capture browser console errors** — Add a handler and log errors during test runs:
  ```js
  page.on("pageerror", (err) => console.log("  [BROWSER ERROR]", err.message));
  ```
  Console errors (especially `TypeError: Cannot read properties of undefined`) often indicate real code bugs, not test problems. Fix them even if tests pass. Note: this only catches unhandled exceptions, not `console.warn`/`console.error` calls inside try/catch — add a `page.on("console", ...)` handler for those if needed.
- **Target a specific result element for assertions** — Avoid reading full page text. Instead, use a selector that isolates the result panel. Common patterns:
  * Tab-based UI: the active tab panel (`.tab-content.active`, `[role="tabpanel"]`)
  * Single-result popup: `[role="dialog"]`
  * Chat/conversation view: the last `.message` or `nth-last-child` result element (command history accumulates — don't read the whole chat log)

**Spinning up long-running dev servers:**
- Use `setsid` to detach the process from the shell session so it survives the bash tool's timeout [see Command Execution](#command-execution)
- **Record the PID on start** — Save the PID so cleanup can kill by recorded PID instead of port-based guessing:
  ```bash
  # Node.js (Next.js, Nuxt, Vite dev server) — $! captures the setsid PID
  setsid npx nuxt dev --port 3000 --host 0.0.0.0 > /tmp/nuxt-dev.log 2>&1 &
  echo $! > /tmp/nuxt-dev.pid

  # Python (FastAPI/uvicorn) — capture PID via $! inside bash -c
  setsid bash -c 'uv run uvicorn app:create_app --factory --port 8000 > /tmp/server.log 2>&1 & echo $! > /tmp/server.pid'
  ```
- **Restart the server if you rebuild the frontend** — The server caches built SPA files (e.g. `web/dist/`) in memory. After `npm run build` or equivalent, read the saved PID, kill the old server (`kill $(cat /tmp/nuxt-dev.pid)`), and start a new one.
- **Check port availability before starting — don't kill foreign processes** — Before starting a server, verify the port is free with `ss -tlnp`. If a process occupies it:
  - **If it's your own orphaned server** (from a prior session): clean it up by recorded PID, or `fuser -k <port>/tcp` as fallback.
  - **If it's a foreign process** (you didn't start it): use a different port instead. Never kill processes you didn't start.
- **Find a free port dynamically** — Instead of guessing which port is free, allocate one:
  ```bash
  PORT=$(python3 -c "import socket; s=socket.socket(); s.bind(('',0)); print(s.getsockname()[1]); s.close()")
  ```
  Then pass it via `--port $PORT` (most dev servers support this flag). This guarantees no conflicts and never kills a foreign process.

### Data isolation
- Do **not** pollute the production database — test on a COPY
- If test credentials are required, look for `.dev` files
- **Clone the data directory before any test run.** This guarantees you can restore the original state regardless of what happens during testing:
  ```bash
  cp -r ~/.local/share/<app>/ ~/tmp/<app>-backup/
  # ... run tests, which modify the live data ...
  rm -rf ~/.local/share/<app>/
  mv ~/tmp/<app>-backup/ ~/.local/share/<app>/
  ```
  The `~/tmp/` directory (your home, private) is used instead of `/tmp/` (world-readable on some systems).
- **If the app supports a custom database path** (check CLI flags or config), use a temp file instead — no clone needed:
  ```bash
  uv run <app> --db /tmp/test.db
  rm -f /tmp/test.db
  ```
  The clone approach above is the universal fallback when the app doesn't support custom DB paths.

### Test credentials
- look for `./.dev`
- ask user if necessary

### Cleanup

After testing is complete, clean up all processes and resources you created:

- **Kill servers you started** — If you saved the PID on start, kill by PID file:
  ```bash
  kill $(cat /tmp/nuxt-dev.pid) 2>/dev/null
  rm -f /tmp/nuxt-dev.pid
  ```
  If you didn't record the PID, fall back to `fuser -k <port>/tcp`.
- **Restore backed-up data** — If you cloned a data directory for testing, restore it. Data isolation is worthless without cleanup.
- **Remove temp files** — Delete any test databases, temp directories, or artifacts created during testing.

If in doubt about whether a process is yours to kill, refer to [Port & Process Management](#port--process-management).
