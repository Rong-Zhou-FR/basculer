# Model Tier Recommendations

## Context

- **Stack**: JavaScript (Vue.js + Nest.js) and Python
- **Goal**: Production-grade code
- **Cost**: Pay-per-token, billed pro rata - minimize cost

## Agent Task Descriptions

### Copilot
**What it does**: Assists the user with direct coding tasks - autocomplete, simple implementations, quick fixes.

**Examples for our stack**:
- Write a Vue.js component template with props
- Generate a Nest.js service method boilerplate
- Create a Python utility function (e.g., data transformation)
- Complete partially written code
- Quick refactoring within a single file

### Architect
**What it does**: Designs system architecture, evaluates tech choices, creates high-level plans.

**Examples for our stack**:
- Decide between Vue 3 Composition API vs Options API for a feature
- Design Nest.js module structure for a new microservice
- Choose between SQL vs NoSQL for a specific data requirement
- Plan migration strategy from REST to GraphQL
- Evaluate Python async patterns (asyncio vs threading)

### Refactorer
**What it does**: Improves existing code quality, applies patterns, restructures for maintainability.

**Examples for our stack**:
- Extract Vue.js component logic into composables
- Refactor Nest.js controller to follow DDD patterns
- Convert Python class to dataclass or pydantic model
- Apply SOLID principles to a module
- Break down a large Python module into packages

### Tester
**What it does**: Creates and runs tests, improves coverage, ensures code correctness.

**Examples for our stack**:
- Write Jest/Vitest unit tests for a Vue.js component
- Create pytest tests for a Python service
- Add E2E tests with Playwright for a Nest.js API endpoint
- Generate mock objects for Vue composables
- Analyze test coverage and suggest missing cases

### Debugger
**What it does**: Diagnoses and fixes bugs, analyzes errors, finds root causes.

**Examples for our stack**:
- Trace a Vue.js hydration mismatch error
- Debug Nest.js dependency injection issues
- Investigate Python memory leaks
- Analyze TypeScript compilation errors
- Find cause of async/await race conditions

### Reviewer
**What it does**: Reviews code for quality, security, best practices - acts as quality gate.

**Examples for our stack**:
- Check Vue.js component for performance issues (re-renders, unnecessary watchers)
- Review Nest.js guard/decorator implementation for security
- Scan Python code for security vulnerabilities (SQL injection, hardcoded secrets)
- Verify adherence to team coding conventions
- Flag potential performance bottlenecks

### Explore
**What it does**: Quickly finds and understands code - navigation, symbol lookup, codebase search.

**Examples for our stack**:
- Find where a Vue.js composable is defined
- Locate all API endpoints in a Nest.js module
- Search for Python model definitions across the codebase
- Understand file structure of a new feature directory
- Find usage of a specific TypeScript interface

### Planner
**What it does**: Orchestrates team collaboration, creates implementation plans, coordinates agents.

**Examples for our stack**:
- Break down a feature into tasks for @architect, @refactorer, @tester
- Plan a migration strategy involving multiple agents
- Coordinate a refactoring effort across the codebase
- Create a full implementation plan from an idea

### Expert
**What it does**: Handles unsolvable problems that other agents cannot resolve - last resort.

**Examples for our stack**:
- Solve a complex architectural decision with no clear best choice
- Debug an intricate race condition across Vue + Nest + Python
- Design a novel authentication pattern for multi-tenant system
- Resolve conflicting requirements from multiple agents

## Factor Priority by Agent

| Agent | Reasoning | Speed | Cost | Context | Tool Use |
|-------|-----------|-------|------|---------|----------|
| Copilot | Low | **High** | **High** | Single file | Basic |
| Architect | **Very High** | Low | Low | Full project | Medium |
| Refactorer | Medium-High | Medium | Medium | Multi-file | High |
| Tester | Medium | Medium | Medium | Full file | High |
| Debugger | Medium | **High** | **High** | Logs + code | High |
| Reviewer | **High** | Low | Medium | Full diff | Basic |
| Explore | Low | **Very High** | **High** | File structure | Basic |
| Planner | **Very High** | Low | Low | Full context | High |
| Expert | **Very High** | Low | Low | Variable | High |

## Factor Definitions

### Reasoning

How much logical analysis, tradeoff evaluation, and complex problem-solving the tasks require.

| Level | Description | Examples |
|-------|-------------|----------|
| **Low** | Straightforward implementation, syntax, template usage | Autocomplete, simple function, component boilerplate |
| **Medium** | Understand code context, apply patterns, moderate analysis | Refactoring, test generation, bug triage |
| **High** | Multi-file analysis, security evaluation, quality assessment | Code review, pattern selection, bug root cause |
| **Very High** | Complex tradeoff analysis, system design, novel solutions | Architecture decisions, expert-level debugging |

### Speed

How critical response time is for the task. Measured in seconds per response.

| Level | Description | Target Latency |
|-------|-------------|----------------|
| **Low** | Thoroughness matters more than speed | 10-30s acceptable |
| **Medium** | Balance between speed and quality | 3-10s acceptable |
| **High** | Fast feedback important | 1-3s acceptable |
| **Very High** | Near-instant response critical | <1s expected |

### Cost

How sensitive the task is to token costs. Based on call volume and value delivered.

| Level | Description | Strategy |
|-------|-------------|----------|
| **Low** | High-impact, infrequent calls justify expense | Use best model regardless of cost |
| **Medium** | Moderate volume, balance cost/quality | Mid-tier models, some optimization |
| **High** | High volume, low complexity | Use cheapest viable model |

### Context

How much code/file context the model needs to see to do the task effectively.

| Level | Description | What's Needed |
|-------|-------------|----------------|
| **Single file** | Current file only | <500 lines |
| **Full file** | Entire file being worked on | 500-2000 lines |
| **Multi-file** | Several related files | 2-5 files |
| **Full diff** | All changes in a PR/commit | <5000 lines changed |
| **Full project** | Entire codebase or large portions | 10000+ lines |
| **Variable** | Depends on problem complexity | Case-by-case |

### Tool Use

How much the model needs to interact with tools (search, execute, file operations).

| Level | Description | Tools Typically Used |
|-------|-------------|---------------------|
| **Basic** | Read files, some searches | read, grep, glob |
| **Medium** | Search + some file operations | read, grep, glob, find_file |
| **High** | Frequent tool interactions | All tools - read, write, edit, search, bash, task |

## Cost Optimization Strategy

- **Use fast/cheap models for 80% of tasks**: @copilot, @explore, @debugger initial triage
- **Reserve expensive models for**: @architect, @planner, @expert decisions
- **Tiered approach**: Start with fast model, escalate if complexity exceeds threshold
- **Cache context**: Build persistent context for agents that need it (@architect, @planner)

## Tier Definitions

### Fast / Lightweight
- Low reasoning requirements
- Single file or small context
- High volume, repetitive tasks
- Speed critical
- Lower cost acceptable

### Mid-Tier
- Moderate reasoning capability
- Full file to multi-file context
- Balance of speed and quality
- Most common tasks fall here

### High-Reasoning
- Complex analysis and planning
- Full project context
- Deep tradeoff reasoning
- Quality over speed
- Higher cost justified

### Highest Tier (Expert)
- Unsolvable problems only
- Novel solution design
- Deep domain expertise
- Slowest but most capable
- Most expensive - use sparingly