# OpenCode Config Reload Behavior

## Rule
**OpenCode config changes only take effect after restart.**

## Implications
1. If an OpenCode feature fails after config change → ask user to restart OpenCode before testing again
2. Model changes, MCP changes, agent changes all require restart
3. No hot-reload for config changes

## Workflow
```
Change config → Feature fails → Ask: "Please restart OpenCode and test again"
```

## History
- 2025-04-30: Documented config reload behavior