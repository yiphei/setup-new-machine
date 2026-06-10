#!/usr/bin/env bash
# Installs the Ghostty config from this repo onto the current machine.
# Usage: ./scripts/setup-ghostty.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$REPO_DIR/ghostty"
DEST_DIR="$HOME/.config/ghostty"

if [[ ! -f "$SRC_DIR/config" ]]; then
  echo "error: $SRC_DIR/config not found" >&2
  exit 1
fi

# Idempotent: skip if the installed config already matches
if [[ -e "$DEST_DIR/config" ]] && cmp -s "$SRC_DIR/config" "$DEST_DIR/config"; then
  echo "Ghostty config already up to date at $DEST_DIR — nothing to do."
  exit 0
fi

# Back up an existing (different) config before overwriting
if [[ -e "$DEST_DIR/config" ]]; then
  backup="$DEST_DIR/config.bak"
  echo "Backing up existing config to $backup"
  mv "$DEST_DIR/config" "$backup"
fi

mkdir -p "$DEST_DIR"
cp "$SRC_DIR/config" "$DEST_DIR/config"

echo "Ghostty config installed to $DEST_DIR"
echo "Reload Ghostty (cmd+shift+,) or restart it to apply."
