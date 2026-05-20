---
name: Feature request
about: Suggest a new feature for OpenCode
title: 'Add model fallback/failover support'
labels: enhancement
assignees: ''

---

## Problem

Currently, OpenCode does not support automatic fallback to an alternate model when the primary model fails. This causes issues when:
- API errors occur
- Rate limits are hit
- Timeouts occur
- Model is temporarily unavailable

Users currently must manually switch providers/models when issues occur, which disrupts workflow.

## Proposed Solution

Add support for fallback models at configuration level:

1. **Model Priority List** - Allow specifying multiple models in priority order:
```json
{
  "model": ["deepseek-ai/DeepSeek-V4-Pro", "opencode/gpt-5.1-codex"]
}
```

2. **Provider-level fallback** - If one provider fails, automatically try the next available provider

3. **Failure detection** - Automatically detect:
   - API errors
   - Rate limits (429)
   - Timeouts
   - Model not found (404)

## Use Cases

- Handle API rate limits gracefully by switching to backup model
- Automatic recovery from temporary provider outages
- Cost optimization by trying cheaper models first, escalating if needed

## Workaround (Current)

The `small_model` config exists but only applies to lightweight tasks like title generation - not general fallback behavior.

## Priority

Medium - This would improve reliability for production use cases.
