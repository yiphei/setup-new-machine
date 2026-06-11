#!/bin/bash
set -euo pipefail
# Claude Code WorktreeCreate hook
# Restores core.hooksPath so that git worktree add triggers .githooks/post-checkout naturally.
#
# Set WORKTREE_BASE to control the starting point:
#   WORKTREE_BASE=current       — use the current branch (resolved from the invoking shell's PWD)
#   WORKTREE_BASE=<branch-name> — use an explicit branch/ref
#   (unset)                     — default to origin/main

# Read input from stdin (Claude Code passes JSON via stdin)
INPUT=$(cat)

# Parse fields from the input JSON
# Actual schema: { session_id, transcript_path, cwd, hook_event_name, name }
WORKTREE_NAME=$(echo "$INPUT" | jq -r '.name')
CWD=$(echo "$INPUT" | jq -r '.cwd')

# Resolve base ref from WORKTREE_BASE env var
if [ "${WORKTREE_BASE:-}" = "current" ]; then
    # Resolve HEAD from $CLAUDE_PROJECT_DIR (the directory where claude was launched),
    # NOT from $CWD (which points to the main worktree and may have a stale HEAD).
    BASE_REF="$(git -C "$CLAUDE_PROJECT_DIR" rev-parse HEAD)"
elif [ -n "${WORKTREE_BASE:-}" ]; then
    BASE_REF="$WORKTREE_BASE"
else
    BASE_REF="$(git -C "$CWD" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/||' || true)"
    [ -z "$BASE_REF" ] && BASE_REF="origin/main"
fi

# Create worktree at the documented default location — this triggers .githooks/post-checkout
WORKTREE_PATH="$CWD/.claude/worktrees/$WORKTREE_NAME"
BRANCH_NAME="worktree-$WORKTREE_NAME"
mkdir -p "$CWD/.claude/worktrees"
# Delete stale branch from a previous worktree with the same name, if any
git -C "$CWD" branch -D "$BRANCH_NAME" >/dev/null 2>&1 || true
git -C "$CWD" worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME" "$BASE_REF" >/dev/null 2>&1

# Output the absolute path (required by Claude Code)
echo "$WORKTREE_PATH"
exit 0
