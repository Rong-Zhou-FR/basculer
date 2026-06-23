# Browser tool: localhost vs 127.0.0.1

## Symptom
Starting a dev server (e.g. `npx nuxi dev --port 3300` or `python3 -m http.server 3300`), then using the browser tool to open `http://localhost:3300/` yields `ERR_CONNECTION_REFUSED` — even though `curl http://localhost:3300/` returns HTTP 200 from the same bash context.

## Root Cause (NOT container isolation)
The agent's "different container" explanation is **wrong for this environment**. Both bash and Chromium run in the same network namespace (`net:[4026531840]`), same host (`libres`), same user.

The real issue is **IPv4/IPv6 resolution mismatch**:

- Python's `http.server` (and many dev servers like `nuxi dev`) default to binding **IPv4 only** (`0.0.0.0`) — NOT IPv6 (`::`).
- The system resolver (`getent hosts localhost`) returns `::1` before `127.0.0.1`.
- Chromium (via Happy Eyeballs or its internal DNS resolution) resolves `localhost` to `::1` first, then fails to connect because the server isn't listening on IPv6.
- `curl` uses the system resolver which happens to prefer IPv4 in this case (or falls back).

## Fix
**Use `127.0.0.1` instead of `localhost`** when opening the browser tool:

```
browser open http://127.0.0.1:3300/
```

This bypasses the IPv6 resolution issue entirely.

## Alternative (server-side)
If you control the dev server, bind to `::` (IPv6 any) instead of `0.0.0.0` (IPv4 any). On systems with `net.ipv6.bindv6only=0` (default on Linux), this accepts **both** IPv4 and IPv6 connections:

```bash
python3 -m http.server 3300 --bind ::
```

Or with Node.js/Nuxt:
```bash
npx nuxi dev --port 3300 --host ::
```

## Verification
```bash
# Test IPv6 connectivity to the server:
curl -s -o /dev/null -w '%{http_code}' http://[::1]:3300/
# Returns 000 if server isn't listening on IPv6
```

## Discovered
2025-06-23 — by empirical test after suspecting the "container isolation" claim was wrong.
