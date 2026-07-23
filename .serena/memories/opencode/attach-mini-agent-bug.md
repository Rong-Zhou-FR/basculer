# opencode attach --mini ignores --agent/--model flags

## Issue
https://github.com/anomalyco/opencode/issues/38483

## Root Cause
`packages/opencode/src/cli/cmd/attach.ts` does not:
1. Define `--agent` or `--model` in its yargs builder
2. Forward `args.agent`, `args.model`, or `args.prompt` to `runMini()`

Compare with `tui.ts` which forwards all three correctly.

## Downstream Effect
- `CMD_MASTER` in `lighter-dev.bash` uses `OPENCODE_CONFIG_CONTENT` to try setting default_agent to gitmaster
- But `OPENCODE_CONFIG_CONTENT` is client-side only — cannot affect the server's agent selection
- The server always uses its own `default_agent` (copilot/build)

## Fix (6 lines in attach.ts)
1. Add `.option("model", ...)` and `.option("agent", ...)` to builder
2. Add `model: args.model, agent: args.agent, prompt: args.prompt` to the `runMini()` call

## Workaround
None without upstream fix. The script must wait for the fix to land in a release, then change:
```bash
CMD_MASTER="opencode attach ${OPCODE_SERVE_URL} --mini --agent gitmaster"
```
