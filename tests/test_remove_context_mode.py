"""Tests for context-mode removal from opencode configuration.

Verifies:
- context-mode/ data directory is gone
- No "contextMode" MCP entry in opencode.jsonc
- No "context-mode" plugin entry in opencode.jsonc
- No orphaned references to context-mode in any opencode config files
- opencode.jsonc remains valid JSONC
- AGENTS.md and explore.md no longer reference contextMode tools
- Serena is still correctly configured
"""

import json
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
OPENCODE_DIR = REPO_ROOT / "opencode-config" / "opencode"
CONFIG_JSONC = OPENCODE_DIR / "opencode.jsonc"
CONTEXT_MODE_DIR = OPENCODE_DIR / "context-mode"
AGENTS_MD = OPENCODE_DIR / "AGENTS.md"
EXPLORE_AGENT = OPENCODE_DIR / "agents" / "explore.md"
EXPLORE_COMMAND = OPENCODE_DIR / "commands" / "explore.md"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _read_jsonc():
    """Strip single-line C-style comments (//) then parse as JSON.

    Only strips lines where the first non-whitespace is '//', which
    correctly preserves URLs like 'https://...' inside JSON strings.
    """
    text = CONFIG_JSONC.read_text()
    lines = [
        line for line in text.splitlines()
        if not line.strip().startswith("//")
    ]
    return json.loads("\n".join(lines))


# ---------------------------------------------------------------------------
# 1. Data directory
# ---------------------------------------------------------------------------

def test_context_mode_directory_removed():
    """The context-mode data directory must no longer exist."""
    assert not CONTEXT_MODE_DIR.exists(), (
        f"context-mode/ directory still exists at {CONTEXT_MODE_DIR}"
    )


# ---------------------------------------------------------------------------
# 2. opencode.jsonc — MCP entry
# ---------------------------------------------------------------------------

def test_no_contextmode_mcp_entry():
    """The 'contextMode' key must not be present in the mcp section."""
    config = _read_jsonc()
    mcp = config.get("mcp", {})
    assert "contextMode" not in mcp, (
        "'contextMode' MCP entry still present in opencode.jsonc"
    )


def test_no_contextmode_plugin():
    """The 'plugin' array must not contain 'context-mode'."""
    config = _read_jsonc()
    plugins = config.get("plugin", [])
    assert "context-mode" not in plugins, (
        f"'context-mode' still listed in plugin array: {plugins}"
    )


def test_file_is_valid_jsonc():
    """opencode.jsonc must have valid JSON structure."""
    config = _read_jsonc()
    assert "mcp" in config, "Missing 'mcp' key"
    assert "provider" in config, "Missing 'provider' key"
    assert "agent" in config, "Missing 'agent' key"


# ---------------------------------------------------------------------------
# 3. No orphaned references elsewhere in config files
# ---------------------------------------------------------------------------

def test_no_contextmode_references_in_other_config_files():
    """No other .jsonc or .json files at the opencode level reference context-mode."""
    for cfg_file in OPENCODE_DIR.glob("*.jsonc"):
        if cfg_file.name == "opencode.jsonc":
            continue
        text = cfg_file.read_text()
        assert "context-mode" not in text and "contextMode" not in text, (
            f"context-mode reference in {cfg_file.relative_to(REPO_ROOT)}"
        )


# ---------------------------------------------------------------------------
# 4. AGENTS.md no longer references ctx_* tools
# ---------------------------------------------------------------------------

def test_agents_md_no_ctx_search():
    """AGENTS.md must not reference ctx_search (removed with context-mode)."""
    text = AGENTS_MD.read_text()
    assert "ctx_search" not in text, (
        "AGENTS.md still references ctx_search (from removed context-mode)"
    )


def test_agents_md_no_ctx_execute():
    """AGENTS.md must not reference ctx_execute/ctx_batch_execute."""
    text = AGENTS_MD.read_text()
    assert "ctx_execute" not in text, (
        "AGENTS.md still references ctx_execute (from removed context-mode)"
    )
    assert "ctx_batch_execute" not in text, (
        "AGENTS.md still references ctx_batch_execute (from removed context-mode)"
    )
    assert "ctx_fetch" not in text, (
        "AGENTS.md still references ctx_fetch (from removed context-mode)"
    )


# ---------------------------------------------------------------------------
# 5. Agent/command files no longer reference contextMode tools
# ---------------------------------------------------------------------------

def test_agent_explore_no_contextmode():
    """agents/explore.md must not reference contextMode tools."""
    text = EXPLORE_AGENT.read_text()
    assert "contextMode" not in text, (
        "agents/explore.md still references contextMode tools"
    )


def test_all_agents_no_contextmode():
    """No agent .md file anywhere in agents/ may reference contextMode."""
    for agent_file in (OPENCODE_DIR / "agents").glob("*.md"):
        text = agent_file.read_text()
        assert "contextMode" not in text, (
            f"{agent_file.relative_to(REPO_ROOT)} still references contextMode"
        )


def test_command_explore_no_contextmode():
    """commands/explore.md must not reference contextMode tools."""
    text = EXPLORE_COMMAND.read_text()
    assert "contextMode" not in text, (
        "commands/explore.md still references contextMode tools"
    )


# ---------------------------------------------------------------------------
# 6. Serena is still correctly configured (smoke test)
# ---------------------------------------------------------------------------

def test_serena_still_configured():
    """The serena MCP server must still be present and enabled."""
    config = _read_jsonc()
    serena = config["mcp"]["serena"]
    assert serena["type"] == "local"
    assert serena["enabled"] is True
    assert serena["command"] == ["serena", "start-mcp-server", "--project-from-cwd"]
