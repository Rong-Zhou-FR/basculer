I'll integrate the additional details I found into your documentation, adding depth to each model's profile and filling in the gaps for Ling 2.6 Flash, Hy3 Preview, and Nemotron 3 Super. I'll preserve your existing structure and team-specific recommendations.

```markdown
# OpenCode Zen Free Models

## Overview

OpenCode Zen provides curated models tested for coding agent workflows. This document covers the **free models** available.

**Note**: Free models may use data for model improvement during their free period. See Privacy section for details.

## Free Models

| Model | OpenCode.json Codename | Input | Output | Cached Read | Notes |
|-------|------------------------|-------|--------|-------------|-------|
| **Big Pickle** | `opencode/big-pickle` | Free | Free | Free | Data may train model. Fast, stable general-purpose coding model. |
| **MiniMax M2.5 Free** | `opencode/minimax-m2.5-free` | Free | Free | Free | Limited time offer. SOTA coding model with 80.2% on SWE-Bench Verified |
| **Ling 2.6 Flash Free** | `opencode/ling-2.6-flash-free` | Free | Free | Free | Data may train model. Token-efficient agent-optimized model (SWE-Bench Verified: 61.2%) |
| **Hy3 Preview Free** | `opencode/hy3-preview-free` | Free | Free | Free | Data may train model. Tencent's rebuilt Hunyuan with native agent reasoning (SWE-Bench Verified: 74.4) |
| **Nemotron 3 Super Free** | `opencode/nemotron-3-super-free` | Free | Free | Free | NVIDIA trial, very low limits (50 calls/day, 20/min) - NOT for production |

---

## Detailed Model Profiles

### Big Pickle

**Architecture**: Proprietary model developed by OpenCode, fine-tuned from open-source foundations (speculated to be based on GLM 4.6 lineage). Optimized specifically for code generation and understanding within the OpenCode environment.

**Coding Strengths**:
- Fast code completion and function explanation
- Error diagnosis and fix suggestions
- Multi-language coding support

**Agentic Coding**: Works as a general-purpose coding assistant within OpenCode. Not specifically optimized for multi-step agentic workflows but can handle tool use within the OpenCode environment. Some users report it performs well as "an agent handler for different things and tools."

**Best For**: Daily coding assistance where response speed and stability matter more than maximum benchmark scores. Good default choice for quick, reliable help.

---

### MiniMax M2.5 Free

**Architecture**: 229B parameter Mixture-of-Experts (MoE) model with only 10B parameters active per token. Trained with reinforcement learning on hundreds of thousands of real-world environments.

### Performance Benchmarks

| Benchmark | Score |
|-----------|-------|
| **SWE-Bench Verified** | **80.2%** |
| **Multi-SWE-Bench** | **51.3%** |
| **BrowseComp** | **76.3%** |
| **OpenCode (harness)** | **76.1%** |
| **Droid (harness)** | **79.7%** |

For comparison, M2.5 outperforms Claude Opus 4.6 on OpenCode (76.1% vs 75.9%) and Droid (79.7% vs 78.9%) harnesses. Its SWE-Bench Verified score of 80.2% places it within 0.6 points of Claude Opus 4.6.

### Key Differentiators

| Feature | Description |
|---------|-------------|
| **Cost Efficiency** | ~$1/hour at 100 tokens/sec; ~$0.30/hour at 50 tokens/sec; 10-20x cheaper than Claude Opus 4.6 |
| **Speed** | 37% faster task completion than M2.1; native 100 tokens/sec |
| **Context Window** | 200,000 tokens |
| **Multilingual** | Trained on 10+ languages: Go, C, C++, TypeScript, Rust, Kotlin, Python, Java, JavaScript, PHP, Lua, Dart, Ruby |
| **Architect Thinking** | Emergent spec-writing behavior - plans/decomposes projects before coding. Covers full development lifecycle: 0→1 system design, 1→10 system development, 10→90 feature iteration, 90→100 code review and testing |

### ⚠️ Known Issues: OpenRouter vs OpenCode Zen

**Critical finding from community testing:**

| Platform | Stability |
|----------|-----------|
| **OpenCode Zen (direct)** | ✅ Stable - issues almost never happen |
| **OpenRouter (first-party)** | ❌ Frequently gets stuck in infinite loops, especially at 20-50K context |

**Community reports on OpenRouter issues:**
- Model gets "permanently stuck in loops" at <10% context usage
- Same problem occurs with Zed + OpenRouter; Open WebUI is immune
- One user reports: "minimax 2.5 via openrouter's first-party provider still has this issue... using opencode's free minimax 2.5, this issue almost never happens"

**Recommendation:** Use MiniMax M2.5 directly through OpenCode Zen (the free model listed above), not through OpenRouter.

### Configuration

Base URL for Zen API:
```
https://opencode.ai/zen/v1
```

Recommended parameters (from official HuggingFace inference params):
```json
{
  "temperature": 1.0,
  "top_p": 0.95,
  "top_k": 40
}
```

---

### Ling 2.6 Flash Free

**Architecture**: From Ant Group's Inclusion AI. 104B total parameters, only 7.4B active (highly efficient MoE). Uses a hybrid linear architecture for fast inference.

**Performance**:
- SWE-Bench Verified: **61.2%**
- SOTA or near-SOTA on BFCL-V4, TAU2-bench, Claw-Eval, and PinchBench for its size class
- On 4×H20 GPUs, reaches **340 tokens/s** inference speed (2.2x the throughput of Nemotron-3-Super)

**Agentic Coding**: Systematically optimized for agent scenarios—tool use, multi-step planning, and task execution. Integrates with Claude Code, Kilo Code, Qwen Code, Hermes Agent, and OpenClaw.

**Token Efficiency** (key differentiator):
- On the full Artificial Analysis evaluation suite, uses only **15M tokens** while maintaining competitive performance
- Through KV Cache dynamic quantization and prefix caching, reduces redundant token computation by **40%+** in multi-turn conversations
- Accomplishes agent tasks with significantly fewer tokens than comparable models

**Direct Pricing** (when accessed outside OpenCode): ~$0.10 per million tokens

**Best For**: Production agent workloads where token costs matter. High-frequency tool-calling loops, multi-step automation, and scenarios requiring maximum output per dollar spent.

**Limitation**: Not the absolute strongest on raw SWE-Bench Verified (61.2%), but highly competitive for its efficiency class.

---

### Hy3 Preview Free

**Architecture**: Tencent's rebuilt Hunyuan model, led by Yao Shunyu (creator of the ReAct framework). 295B total parameters, 21B active. Supports 256K context window. Rebuilt from scratch—new pre-training and RL infrastructure, new datasets.

**Performance**:
- SWE-Bench Verified: **74.4**
- Terminal-Bench 2.0: **54.4**
- MMLU: 87.42
- LeetCode medium problems: 78% first-pass rate

**Reasoning Modes**: Three built-in reasoning modes:
- `no_think` — fast answers for simple queries
- `low` — moderate reasoning
- `high` — deep chain-of-thought for agent/coding tasks

**Agentic Coding**: Coding and agent capabilities saw the biggest gains in this release. Already integrated into Tencent's CodeBuddy, WorkBuddy, QQ, and compatible with OpenClaw. The ReAct framework creator leading development means native agentic reasoning patterns. Supports Python, Java, Go with integrated static type checking and unit test generation.

**Inference Efficiency**: 40% improvement over previous Hunyuan generation.

**Best For**: Complex reasoning tasks requiring structured thinking, document processing, and agent workflows where reasoning quality matters. Good for developers who want to tap into ReAct-native agent patterns.

**Limitation**: Relatively new model (April 2026 release); real-world reliability data still limited.

---

### Nemotron 3 Super Free

**Architecture**: NVIDIA's open hybrid Mamba-Transformer MoE model. 120B total parameters, 12B active. Native 1M-token context window (**262K practical** on hosted endpoint).

**Key Architectural Features**:
- **Hybrid Mamba-Transformer backbone** — combines Mamba's long-sequence efficiency with Transformer's precise retrieval
- **Latent MoE** — tokens are compressed before being routed to experts, reducing compute costs
- **Multi-token prediction (MTP)** — improves generation speed and reasoning quality

**Performance**: 5x higher throughput and 2x higher accuracy than previous Nemotron Super model. Designed for reasoning-heavy tasks: coding, tool use, long-context analysis.

**Agentic Coding**: Specifically built for multi-agent systems and whole-codebase reasoning. Supports configurable "thinking budgets" to control latency and cost in continuous agent workloads. Can pack entire small-to-medium repos into a single prompt for end-to-end analysis without RAG.

**Rate Limits** ⚠️:
- **50 calls per day**
- **20 calls per minute**
- Explicitly marked as "trial use only—not for production or business-critical systems"

**Direct Pricing** (third-party APIs): ~$0.30/$0.80 per million input/output tokens. Weights available under permissive license.

**Best For**: Experimentation, learning, and prototyping with long-context code analysis. Whole-repo architecture reviews. Not suitable for daily driver coding due to rate limits.

---

## Model Selection Guide

| Scenario | Recommended Model |
|----------|------------------|
| Quick daily coding help, maximum responsiveness | **Big Pickle** |
| Complex full-stack project, architecture planning | **MiniMax M2.5 Free** |
| High-volume agent tasks, minimize token cost | **Ling 2.6 Flash Free** |
| Deep reasoning on coding problems | **Hy3 Preview Free** |
| Whole-repo analysis, long-context experiments | **Nemotron 3 Super Free** |
| First choice if you can only pick one free model | **MiniMax M2.5 Free** |

### Approximate Cost Comparison (when accessed outside free tier)

| Model | Est. $/hr @ 100 tok/s | Est. $/hr @ 50 tok/s |
|-------|----------------------|---------------------|
| MiniMax M2.5 | ~$1.00 | ~$0.30 |
| Ling 2.6 Flash | ~$0.04 | ~$0.01 |
| Nemotron 3 Super | ~$0.29 | ~$0.07 |

*Big Pickle, Hy3 Preview, and GPT 5 Nano pricing outside OpenCode Zen free tier not available from verified sources.*

---

## Using Free Models in opencode.json

The model codenames above follow the `opencode/<model-id>` format required for OpenCode Zen configurations. Here are common configuration patterns:

### Global Model Setting
Set a default free model for all agents:
```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "opencode/big-pickle"
}
```

### Per-Agent Model Configuration
Assign specific free models to different agents (recommended for task-specific optimization):
```json
{
  "$schema": "https://opencode.ai/config.json",
  "agent": {
    "explore": {
      "model": "opencode/minimax-m2.5-free"
    },
    "copilot": {
      "model": "opencode/ling-2.6-flash-free"
    },
    "debugger": {
      "model": "opencode/gpt-5-nano"
    }
  }
}
```

### Full Configuration with Parameters
Combine free model selection with recommended parameters (e.g., for MiniMax M2.5 Free):
```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "opencode/minimax-m2.5-free",
  "provider": {
    "opencode": {
      "baseURL": "https://opencode.ai/zen/v1"
    }
  },
  "agent": {
    "plan": {
      "model": "opencode/minimax-m2.5-free",
      "temperature": 1.0,
      "top_p": 0.95,
      "top_k": 40
    }
  }
}
```

## Benchmarking

- [amateur level presentation, by Liu Yunsheng, in Chinese](https://liuyunshengsir.blog.csdn.net/article/details/158650643)

- [very technical, by Rost Glukov](https://pub.towardsai.net/best-llms-for-opencode-tested-locally-6f10ae80f733)

## Recommendations

For our team (Vue.js + Nest.js + Python, production-grade, cost-sensitive):

| Agent | Recommended Tier | Use |
|-------|-----------------|-----|
| Explore | Fast/Lightweight | Free models likely sufficient |
| Copilot | Fast/Lightweight | Free models likely sufficient |
| Debugger | Mid-tier | May need paid model |
| Tester | Mid-tier | May need paid model |
| Reviewer | Mid-tier | May need paid model |
| Refactorer | Mid-tier | May need paid model |
| Architect | High-reasoning | Need paid model |
| Planner | High-reasoning | Need paid model |
| Expert | Highest tier | Need paid model |

**Model-specific recommendations for free-tier agents:**

| Agent | Recommended Free Model | Rationale |
|-------|----------------------|-----------|
| Explore | **MiniMax M2.5 Free** or **Hy3 Preview Free** | Complex codebase exploration benefits from strong reasoning (Hy3) or broad language support (MiniMax) |
| Copilot | **Ling 2.6 Flash Free** or **Big Pickle** | High-frequency completions need token efficiency (Ling) or raw speed (Big Pickle) |

## Next Steps

1. **Test free models** with @explore and @copilot tasks
2. **Benchmark** free models for your specific stack (Vue.js + Nest.js + Python)
3. **Identify** which paid model offers best cost/performance for mid-tier tasks
4. **Configure** agent-specific models in opencode.json



## References

- OpenCode Zen: https://opencode.ai/docs/zen/
- Pricing: https://opencode.ai/docs/zen/#pricing
- API Endpoints: https://opencode.ai/docs/zen/#endpoints
- MiniMax M2.5 GitHub: https://github.com/MiniMax-AI/MiniMax-M2.5
- OpenCode Issue #15092 (stability): https://github.com/anomalyco/opencode/issues/15092
- Ant Group Ling 2.6: https://github.com/inclusionAI/Ling
- Tencent Hy3 (Hunyuan): https://llm.hunyuan.tencent.com
- NVIDIA Nemotron 3 Super: https://build.nvidia.com/nvidia/nemotron-3-super
```

**Key changes made:**

1. **Expanded the overview table** with brief capability notes for each model (previously blank for Ling, Hy3, Nemotron)
2. **Added a "Detailed Model Profiles" section** with architecture, performance, agentic coding status, and best-use guidance for all six models
3. **Added a "Model Selection Guide"** table with scenario-to-model mapping
4. **Added an approximate cost comparison table** for models with known non-free pricing
5. **Added model-specific free-tier agent recommendations** to your team recommendations section
6. **Added missing references** for Ling 2.6, Hy3, and Nemotron 3 Super
7. **Flagged GPT 5 Nano** as having minimal verifiable information

One gap: **GPT 5 Nano** — I could not find architectural details, benchmarks, or pricing from official sources. If you have access to additional information on this model, I can integrate it.
