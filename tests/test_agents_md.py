"""Tests for opencode-config/opencode/AGENTS.md structure.

Verifies:
- A standalone "Git conventions" subsection exists with commit rules
- No orphaned "- IF" line
- All workflow phases present and correctly structured
- No duplicate stash rules
"""

from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
AGENTS_MD = REPO_ROOT / "opencode-config" / "opencode" / "AGENTS.md"


def test_file_exists():
    """Sanity check: the file must exist."""
    assert AGENTS_MD.is_file(), f"{AGENTS_MD} not found"


def test_git_conventions_section_present():
    """A standalone 'Git conventions' subsection must exist with commit rules."""
    content = AGENTS_MD.read_text()
    assert "**Git conventions:**" in content, (
        "'**Git conventions:**' subsection header missing"
    )
    # Must mention Conventional Commits (the format reference)
    assert "Conventional Commits" in content, (
        "Conventional Commits rule missing from Git conventions"
    )
    # Must mention GitHub issue references
    assert "#N" in content, (
        "GitHub issue reference rule missing"
    )


def test_no_orphaned_if():
    """The orphaned '- IF' line must be removed."""
    content = AGENTS_MD.read_text()
    assert "  - IF " not in content, "Orphaned '  - IF ' line still present"


def test_before_starting_phase():
    """'Before starting' phase must exist with feature-branch rule."""
    content = AGENTS_MD.read_text()
    assert "**Before starting:**" in content, (
        "'**Before starting:**' phase header missing"
    )
    # The feature-branch rule from old Git conventions must be in this phase
    assert "not working on `main`" in content or "use feature branches" in content, (
        "Feature branch rule missing from Before starting phase"
    )


def test_while_coding_phase():
    """'While coding' phase must exist."""
    content = AGENTS_MD.read_text()
    assert "**While coding:**" in content, (
        "'**While coding:**' phase header missing"
    )


def test_after_implementation_phase():
    """'After implementation' phase must exist with review + commit."""
    content = AGENTS_MD.read_text()
    assert "**After implementation:**" in content, (
        "'**After implementation:**' phase header missing"
    )
    # Must mention asking reviewer/tester
    assert "@reviewer" in content and "@tester" in content, (
        "Reviewer/tester delegation rule missing"
    )
    # Must mention committing changes (via git conventions section)
    assert "commit changes" in content, (
        "'commit changes' rule missing from After implementation phase"
    )


def test_after_completing_unit_phase():
    """'After completing a functional unit' phase must exist."""
    content = AGENTS_MD.read_text()
    assert "**After completing a functional unit:**" in content, (
        "'**After completing a functional unit:**' phase header missing"
    )
    # Must mention merging to main
    assert "Merge to main" in content, (
        "'Merge to main' rule missing from final phase"
    )
    # Must mention closing issues
    assert "Close completed issues" in content, (
        "'Close completed issues' rule missing"
    )
    # Must mention updating docs
    assert "Update `AGENTS.md`" in content, (
        "'Update AGENTS.md' rule missing"
    )


def test_no_duplicate_stash_rules():
    """Stash rule should appear exactly once (was duplicated across old sections)."""
    content = AGENTS_MD.read_text()
    # Count occurrences of "stash" in list items
    stash_lines = [
        line for line in content.splitlines()
        if "stash" in line.lower() and line.strip().startswith("-")
    ]
    assert len(stash_lines) == 1, (
        f"Expected exactly one stash-related rule, found {len(stash_lines)}: {stash_lines}"
    )


def test_workflow_section_has_no_flat_list():
    """The Workflow section should use phased sub-headers, not a flat list."""
    content = AGENTS_MD.read_text()
    # The old flat list items like "- BEFORE starting:" should NOT be present
    assert "- BEFORE starting:" not in content, (
        "Old flat '- BEFORE starting:' list item still present"
    )
    assert "- AFTER implementation:" not in content, (
        "Old flat '- AFTER implementation:' list item still present"
    )
    assert "- WHILE coding:" not in content, (
        "Old flat '- WHILE coding:' list item still present"
    )
