# Super-Bash AGENTS.md

## Overview
Collection of bash utility functions for developer productivity

## Architecture
```
super-bash/
├── bash-dev.bash              # Development helpers
├── bash-autish.bash           # Automation/shell utilities
├── bash-text-opt.bash         # Text processing utilities
├── functions/                 # Modular per‑domain function files
│   ├── A-semantika-nodo-aldoni.bash   # Wrappers for A semantika nodo aldoni
│   ├── A-semantika-arko-aldoni.bash   # Wrapper for A semantika arko aldoni
│   ├── A-semantika-temp.bash          # Template/boilerplate node creation
│   ├── A-semantika-predikato-aldoni-1.bash  # Predicate creation wrapper
│   └── A_enc_generi.bash              # Encrypted agent generi wrapper
├── .enc                     # Encrypted secrets (optional)
└── README.md                # Usage guide (to be added)
```

## Subcomponents
| Component | Purpose |
|-----------|---------|
| bash-dev.bash | Development commands (git, docker, etc.) |
| bash-autish.bash | Shell automation functions |
| bash-text-opt.bash | Text processing/optimization |
| functions/ | Per‑domain function files (sourced individually) |

## Configuration
- Modular by design - source only what you need
- No external dependencies (pure bash)

## Dependencies
- bash 4.0+
- Standard GNU tools (grep, sed, awk, etc.)

## Integration Points
- Can be sourced from any bashrc/profile
- Functions are namespaced to avoid conflicts

## Usage
```bash
# Source all
source ~/.basculer/super-bash/bash-dev.bash

# Or specific file
source ~/.basculer/super-bash/bash-autish.bash
```