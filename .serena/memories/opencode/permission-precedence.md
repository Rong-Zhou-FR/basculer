## OpenCode Permission Precedence

**Last matching rule wins** when evaluating permission rules.

Example:
```yaml
permission:
  task:
    "*": deny
    "orchestrator-*": allow  # This wins for orchestrator-* matches
```

Always put specific rules AFTER general rules to ensure they take precedence.