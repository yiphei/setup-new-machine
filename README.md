# setup-new-machine

Configs and scripts for setting up a new machine.

## Script principles

Every script in this repo should follow best programming principles:

- **Idempotent**: safe to run multiple times — always check whether the intended changes are already present before applying them.
- **Failsafe**: fail fast on errors (`set -euo pipefail`), validate inputs and preconditions, and back up anything before overwriting it.
- **Self-contained**: no assumptions about the working directory — resolve paths relative to the script's own location.
- **Transparent**: print what was done (or skipped) so the user knows the outcome.

## Ghostty

Config lives in `ghostty/`. To install on a new machine:

```sh
./scripts/setup-ghostty.sh
```

This copies the config to `~/.config/ghostty/`, backing up any existing config to `config.bak` first.
