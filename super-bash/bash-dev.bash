#!/bin/bash

repoInit() {
  # Fetch AGENTS-root-template.md
  local agents_root_url="https://api.github.com/repos/Rong-Zhou-FR/ronAI/contents/context-files/AGENTS-root-template.md?ref=main"
  local agents_root_output="./AGENTS.md"

  # Fetch FOSS-software.md (plan template)
  local plan_template_url="https://api.github.com/repos/Rong-Zhou-FR/ronAI/contents/AI-prompts/inventing/FOSS-software.md?ref=main"
  local plan_template_output="./dev/plan/0-idea.md"

  # Fetch AGENTS-module-template.md
  local agents_module_url="https://api.github.com/repos/Rong-Zhou-FR/ronAI/contents/context-files/AGENTS-module-template.md?ref=main"
  local agents_module_output="./dev/examples/AGENTS-module-template.md"

  # Create necessary directories
  mkdir -p "$(dirname "$plan_template_output")"
  mkdir -p "$(dirname "$agents_module_output")"

  # Fetch AGENTS-root-template.md
  if curl -H "Accept: application/vnd.github.raw+json" -sSf "$agents_root_url" -o "$agents_root_output"; then
    echo "Successfully saved to $agents_root_output"
  else
    echo "Error: Failed to fetch AGENTS-root-template.md" >&2
    return 1
  fi

  # Fetch FOSS-software.md
  if curl -H "Accept: application/vnd.github.raw+json" -sSf "$plan_template_url" -o "$plan_template_output"; then
    echo "Successfully saved to $plan_template_output"
  else
    echo "Error: Failed to fetch FOSS-software.md" >&2
    return 1
  fi

  # Fetch AGENTS-module-template.md
  if curl -H "Accept: application/vnd.github.raw+json" -sSf "$agents_module_url" -o "$agents_module_output"; then
    echo "Successfully saved to $agents_module_output"
  else
    echo "Error: Failed to fetch AGENTS-module-template.md" >&2
    return 1
  fi

  # Open the plan template in neovim
  nvim "$plan_template_output"
}

rinit() {
  repoInit
}
