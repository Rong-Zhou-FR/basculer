# Subagent Naming Convention for Tier Services

When creating a subagent for a tier service (like GitHub, Hugging Face, GitLab, etc.), use the pattern `{service-name}er`.

## Examples
- `githubber` - GitHub operations
- `huggingfacer` - Hugging Face operations
- `gitlaber` - GitLab operations (future)
- `awsser` - AWS operations (future)

## Placement
- Global agents: `~/.config/opencode/agents/`
- Per-project agents: `.opencode/agents/`

## Agent File Structure
- YAML frontmatter with: mode, description, temperature, permission
- System prompt with: Focus Areas, Tone & Style, Tool Usage, Guidelines, Error Handling