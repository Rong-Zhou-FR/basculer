# Basculer - Productivity Tweaks Repo Plan

## Project Overview
A collection of productivity tweaks for Debian-based Linux. Users clone, customize, then symlink (for opencode/espanso) or source (for bash) the components they need.

## Current Structure
```
basculer/
├── opencode/           # opencode config
│   ├── agents/         # agent configs
│   ├── context-mode/   # context-mode data
│   ├── opencode.json   # main config
│   └── package.json
├── super-bash/         # bash utility functions
│   ├── bash-dev.bash
│   ├── bash-autish.bash
│   └── bash-text-opt.bash
└── dev/plans/          # planning docs
```

## Planned Structure
```
basculer/
├── opencode/           # (no change)
├── super-bash/         # (no change)
├── espanso/            # NEW: espanso match yml files
│   ├── base.yml        # common matches
│   └── README.md      # usage guide
├── README.md           # NEW: repo overview & setup
└── dev/plans/          # planning docs
```

## Architecture
- **Modular by design**: each tool (opencode, bash, espanso) has its own directory
- **No runtime**: this is a config repo, not an application
- **User-driven**: users pick and choose what they need

## Tech Stack
| Component | Technology | Rationale |
|-----------|------------|------------|
| Shell functions | bash | Debian default shell |
| Text expansion | espanso | Cross-platform, active dev |
| Code assistant config | opencode | Local-first, customizable |

## Implementation Considerations

1. **Espanso organization**:
   - Group matches by category (code, text, git, etc.)
   - Provide a `base.yml` users can include, or individual files they can pick

2. **Bash functions**:
   - Already modularized by file (dev, autish, text-opt)
   - Keep source-able (no execution on import)

3. **Opencode config**:
   - Already has agents/ structure
   - Consider adding a `.env.example` for model API keys

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| User doesn't know what to symlink | Add README with copy-paste examples |
| Config drift as tools update | Version-specific configs, document breaking changes |
| Too many options overwhelm | Provide sensible defaults per component |

## Next Steps
1. Add `espanso/` directory with sample match file
2. Create top-level `README.md` with setup instructions
3. (Optional) Add `.env.example` template for opencode