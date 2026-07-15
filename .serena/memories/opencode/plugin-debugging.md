# opencode Plugin Debugging

## Key URLs
- opencode source: https://github.com/anomalyco/opencode
- Plugin loading pipeline: `packages/opencode/src/plugin/loader.ts`
- Plugin tool registration: `packages/opencode/src/tool/registry.ts`
- Plugin SDK types: `packages/plugin/src/index.ts` and `packages/plugin/src/tool.ts`

## Known pitfalls

### Silent tool registration failure
When a plugin's `@opencode-ai/plugin` version differs from the opencode host version, the plugin loads (logs show success), tools register in the registry, but they are **never surfaced to the agent**. No error is logged. This happens because `fromPlugin()` in `registry.ts` converts tool definitions using zod — mismatched versions produce malformed defs that are silently dropped.

Fix: Ensure the plugin resolves the same `@opencode-ai/plugin` version as the running opencode. Check `opencode --version`, then pin that version in the project's `package.json`. Never install `@opencode-ai/plugin` in a plugin-local `node_modules/`.

### Module resolution shadowing
Bun/Node resolve `import "x"` by walking up from the importing file's directory, looking for `node_modules/x`. A `node_modules/` in a plugin subdirectory shadows parent versions, even if gitignored. This is not just a git concern — it affects runtime.

### Plugin deployment patterns
- **Bad**: Flattened copy of source files in `opencode-config/opencode/plugins/<name>/`. Copies rot independently, accumulate stale node_modules.
- **Good**: Symlink from `opencode-config/opencode/plugins/<name>/` → dev repo `src/`. Single source of truth.
