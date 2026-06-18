# Model Recommendations for Ronzz.org Agents

*At Ronzz.org, we prioritize FOSS (Free and Open Source Software), including LLMs.*

## Context

- **Stack**: JavaScript (Vue.js + Nest.js) and Python
- **Goal**: Production-grade code
- **Priority**: Efficiency and economically-sensitive

## Agent Model Tier Requirements

Based on `opencode/model-comparison.md`:

| Agent | Tier | Reasoning | Speed | Cost | Context |
|-------|------|-----------|-------|------|---------|
| Explore | Fast/Lightweight | Low | Very High | High | File structure |
| Copilot | Fast/Lightweight | Low | High | High | Single file |
| Tester | Mid-tier | Medium | Medium | Medium | Full file |
| Debugger | Mid-tier | Medium | High | High | Logs + code |
| Reviewer | Mid-tier | High | Low | Medium | Full diff |
| Refactorer | Mid-tier | Medium-High | Medium | Medium | Multi-file |
| Architect | High-reasoning | Very High | Low | Low | Full project |
| Planner | High-reasoning | Very High | Low | Low | Full context |
| Expert | Highest | Very High | Low | Low | Variable |

## FOSS Model Recommendations

*Researched via Hugging Face MCP - verified models with permissive licenses*

### Fast/Lightweight (Explore, Copilot)

| Model | License | Context | Downloads | Use Case |
|-------|---------|---------|-----------|----------|
| **Qwen2.5-Coder-1.5B-Instruct** | Apache 2.0 | 32K | 3.9M | Best balance |
| **Qwen2.5-Coder-0.5B** | Apache 2.0 | ~8K | 409K | Ultra-lightweight |
| **DeepSeek-R1-Distill-Qwen-1.5B** | MIT | 64K | 389K | Reasoning light |

**Why**: Fast inference, Apache 2.0/MIT license, high download counts indicating active use.

### Mid-Tier (Tester, Debugger, Reviewer, Refactorer)

| Model | License | Context | Downloads | Use Case |
|-------|---------|---------|-----------|----------|
| **Qwen2.5-Coder-14B-Instruct** | Apache 2.0 | 32K | 3.4M | Best code model |
| **Qwen2.5-Coder-7B-Instruct** | Apache 2.0 | 32K | 12.3M | Balanced performance |
| **DeepSeek-R1-Distill-Qwen-14B** | MIT | 64K | 6.8M | Reasoning + coding |
| **DeepSeek-R1-Distill-Qwen-32B** | MIT | 64K | 24.2M | Higher reasoning |

**Why**: Strong coding benchmarks, MIT/Apache 2.0 licenses, well-maintained.

### High-Reasoning (Architect, Planner)

| Model | License | Context | Downloads | Use Case |
|-------|---------|---------|-----------|----------|
| **DeepSeek-R1** | MIT | 64K | 21.4M | Best reasoning (684B MOE) |
| **DeepSeek-R1-Distill-Qwen-32B** | MIT | 64K | 24.2M | Strong reasoning |
| **Qwen2.5-Coder-32B-Instruct** | Apache 2.0 | 32K | 950K | Large code model |

**Why**: DeepSeek-R1 is SOTA for reasoning, MIT license, 64K context.

### Highest Tier (Expert)

**Recommended**: `DeepSeek-R1` (MIT, 64K context)

Same as high-reasoning but with longer reasoning budget for complex problem-solving.

## Latest Models (Updated April 2026)

### Qwen3 Series (Latest)

| Model | Params | License | Context | Updated |
|-------|--------|---------|---------|---------|
| **Qwen/Qwen3-Coder-Next** | 79.7B | Apache 2.0 | 128K | Feb 2026 |
| Qwen/Qwen3-Coder-Next-FP8 | 79.7B | Apache 2.0 | 128K | Feb 2026 |

### DeepSeek V4 Series (Latest)

| Model | Params | License | Context | Updated |
|-------|--------|---------|---------|---------|
| **DeepSeek-V4-Pro** | 861B | MIT | 128K | Apr 2026 |
| **DeepSeek-V4-Flash** | 158B | MIT | 128K | Apr 2026 |

## Previous Generation (Still Valid)

| Model | Params | License | Context | Status |
|-------|--------|---------|---------|--------|
| Qwen2.5-Coder-0.5B | 0.5B | Apache 2.0 | 8K | ✅ Active |
| Qwen2.5-Coder-1.5B | 1.5B | Apache 2.0 | 32K | ✅ Active |
| Qwen2.5-Coder-7B | 7.6B | Apache 2.0 | 32K | ✅ Active |
| Qwen2.5-Coder-14B | 14.7B | Apache 2.0 | 32K | ✅ Active |
| DeepSeek-R1 | 684B (MoE) | MIT | 64K | ✅ Active |
| DeepSeek-R1-Distill-Qwen-32B | 32.7B | MIT | 64K | ✅ Active |

## License Notes

- **Apache 2.0** (Qwen2.5-Coder): Fully permissive, commercial-friendly ✅
- **MIT** (DeepSeek-R1): Fully permissive, commercial-friendly ✅
- **bigcode-openrail-m** (StarCoder2): Open but has attribution requirements
- **Avoid**: DeepSeek-Coder V1/V2 - shows "license:other" (likely proprietary)

## Implementation

To configure agent-specific models in OpenCode (using latest models):

```json
{
  "agents": {
    "copilot": {
      "model": "Qwen/Qwen2.5-Coder-7B-Instruct"
    },
    "explore": {
      "model": "Qwen/Qwen2.5-Coder-1.5B-Instruct"
    },
    "tester": {
      "model": "Qwen/Qwen2.5-Coder-14B-Instruct"
    },
    "debugger": {
      "model": "Qwen/Qwen2.5-Coder-14B-Instruct"
    },
    "reviewer": {
      "model": "Qwen/Qwen2.5-Coder-14B-Instruct"
    },
    "refactorer": {
      "model": "Qwen/Qwen2.5-Coder-14B-Instruct"
    },
    "architect": {
      "model": "deepseek-ai/DeepSeek-V4-Pro"
    },
    "planner": {
      "model": "deepseek-ai/DeepSeek-V4-Flash"
    },
    "expert": {
      "model": "deepseek-ai/DeepSeek-V4-Pro"
    }
  }
}
```

**Note**: Qwen3-Coder-Next (79.7B) is very large - may want to wait for smaller distilled versions before using in production.

## Context Window Notes

| Model Family | Context |
|--------------|---------|
| Qwen2.5-Coder | 32K tokens |
| DeepSeek-R1 | 64K tokens |

## References

- Qwen2.5-Coder: https://huggingface.co/Qwen/Qwen2.5-Coder-32B-Instruct
- DeepSeek-R1: https://huggingface.co/deepseek-ai/DeepSeek-R1
- HF Search used: `mcp_hugging_face_hub_repo_search` for "code model apache 2.0", "coder model MIT"
