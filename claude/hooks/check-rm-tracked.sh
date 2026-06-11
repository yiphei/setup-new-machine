#!/bin/bash
# PreToolUse hook for rm commands.
# Asks for confirmation only if any target file is gitignored.
# Everything else (tracked or untracked-but-not-ignored) is auto-allowed.

set -e

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

# Extract file arguments from the rm command, skipping flags (anything starting with -)
# shellcheck disable=SC2086
set -- $COMMAND
shift  # remove "rm"

files=()
for arg in "$@"; do
  case "$arg" in
    -*) continue ;;  # skip flags like -r, -f, -rf, etc.
    *)  files+=("$arg") ;;
  esac
done

# If no files found (e.g. rm with only flags), ask to be safe
if [ ${#files[@]} -eq 0 ]; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "ask",
      permissionDecisionReason: "Could not determine target files"
    }
  }'
  exit 0
fi

# Check each file - if any is gitignored, ask
for file in "${files[@]}"; do
  if git check-ignore -q "$file" 2>/dev/null; then
    jq -n --arg file "$file" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "ask",
        permissionDecisionReason: ("File is gitignored: " + $file)
      }
    }'
    exit 0
  fi
done

# No gitignored files - allow
jq -n '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "allow",
    permissionDecisionReason: "No gitignored files in target"
  }
}'
exit 0
