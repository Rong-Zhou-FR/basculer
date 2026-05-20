# Subagent Addressing Conventions

## In Natural Language Commands
When referring to a subagent in prompts/commands to Robotika R, use the `@` notation:
- `@architect` - system design, tech stack decisions
- `@refactorer` - code improvements, restructuring  
- `@reviewer` - code quality, security reviews
- `@tester` - test creation, coverage analysis
- `@debugger` - bug diagnosis, error analysis
- `@explore` - codebase navigation, file finding
- `@planner` - task breakdown, orchestration
- `@expert` - after trying 3+ approaches, searched docs, still stuck

## Tier Service Agents (from naming-conventions/subagent-tier-services)
- `@githubber` - GitHub operations
- `@huggingfacer` - Hugging Face operations

## In Tool Invocations
When Robotika R delegates to subagents via the `task` tool, the `subagent_type` parameter uses the plain name (no `@`):
```
task(subagent_type: "debugger", prompt: "Fix the login error...")
```

## Summary
- **Human-readable references**: Use `@` prefix (`@architect`)
- **Tool parameter**: Use plain name (`subagent_type: "architect"`)
