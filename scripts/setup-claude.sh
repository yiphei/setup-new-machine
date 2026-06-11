#!/usr/bin/env bash
# Installs the Claude Code config from this repo onto the current machine.
# Usage: ./scripts/setup-claude.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$REPO_DIR/claude"
DEST_DIR="$HOME/.claude"

if [[ ! -d "$SRC_DIR" ]]; then
  echo "error: $SRC_DIR directory not found" >&2
  exit 1
fi

# Find all files under SRC_DIR and copy them to DEST_DIR, idempotent and failsafe
files_copied=0
files_skipped=0

while IFS= read -r -d '' src_file; do
  # Compute relative path from SRC_DIR
  rel_path="${src_file#"$SRC_DIR"/}"
  dest_file="$DEST_DIR/$rel_path"
  dest_dir="$(dirname "$dest_file")"

  # Idempotent: skip if dest exists and matches
  if [[ -f "$dest_file" ]] && cmp -s "$src_file" "$dest_file"; then
    echo "  skipped (already up to date): $dest_file"
    ((files_skipped++))
    continue
  fi

  # Failsafe: back up any existing (different) file before overwriting
  if [[ -e "$dest_file" ]]; then
    backup="$dest_file.bak"
    echo "  backing up existing file to: $backup"
    mv "$dest_file" "$backup"
  fi

  # Create destination directory and copy file
  mkdir -p "$dest_dir"
  cp "$src_file" "$dest_file"
  echo "  installed: $dest_file"
  ((files_copied++))
done < <(find "$SRC_DIR" -type f -print0)

# Make all hook scripts executable
if [[ -d "$DEST_DIR/hooks" ]]; then
  chmod +x "$DEST_DIR/hooks"/*.sh 2>/dev/null || true
  echo "  hook scripts marked executable"
fi

echo ""
if [[ $files_copied -gt 0 ]]; then
  echo "Claude Code config installed to $DEST_DIR"
  echo "  $files_copied file(s) copied"
  echo "  $files_skipped file(s) already up to date"
else
  echo "Claude Code config already up to date at $DEST_DIR"
fi
