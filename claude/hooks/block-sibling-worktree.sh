#!/bin/bash
# PreToolUse hook: blocks tool calls that reference paths inside a sibling
# git worktree. Prevents subagents (and main) from drifting out of the
# current worktree and accidentally reading/editing the wrong branch.
#
# Tools covered (`matcher` in settings.json must match):
#   Bash, Read, Edit, Write, MultiEdit, NotebookEdit, Grep, Glob.
# Silently allows (exit 0, no output) when the path is inside the current
# worktree or the tool has no path arguments, so other hooks and permission
# rules still apply normally.
#
# Cases explicitly handled today:
#
#   Current-worktree resolution
#     - Per-call `cwd` read from stdin JSON (set by Claude Code for every
#       tool call; reflects the subagent's worktree, not the parent's).
#     - Fall back to $CLAUDE_PROJECT_DIR, then $PWD, if `cwd` is missing.
#     - `git rev-parse --show-toplevel` to find the worktree root containing
#       that cwd — handles the case where the tool's cwd is a subdir.
#     - `pwd -P` canonicalizes symlinks so comparisons line up with git's
#       physical output (e.g. macOS /tmp -> /private/tmp).
#
#   Sibling enumeration
#     - Dynamic: `git worktree list --porcelain` on every call, so new
#       worktrees (including ones Claude Code itself creates via
#       isolation: "worktree") are picked up without editing this script.
#     - Current worktree is filtered out of the sibling list.
#     - Each sibling is also `pwd -P`'d to normalize symlinks.
#     - If no siblings exist, exit 0 (allow) immediately.
#
#   Path extraction per tool
#     - Bash: tokenize `tool_input.command` with whitespace word-splitting
#       (set -f disables globbing). Strip one leading/trailing `"` or `'`
#       from each token so `cd "/x"` and `bash -c '/x'` are matched. Collect
#       tokens starting with `/` or `~` (tilde is HOME-expanded).
#     - Read / Edit / Write / MultiEdit / NotebookEdit: `tool_input.file_path`.
#     - Grep / Glob: `tool_input.path`.
#     - Any other tool: exit 0 (no path to check).
#
#   Classification (longest-prefix wins)
#     - For each candidate path, find the longest worktree whose root is a
#       prefix of it — considering both CURRENT_WT and every sibling.
#     - If the longest match is the current worktree, allow.
#     - If the longest match is a sibling, deny.
#     - Handles the nested-worktree case: when current is
#       `/repo/.claude/worktrees/foo` and `/repo` is also a worktree,
#       both prefix-match in-tree paths — the longer (current) wins.
#     - Non-absolute paths (relative, not starting with `/` after tilde
#       expansion) are skipped; they always refer to the current worktree.
#
#   Output
#     - On deny: a `hookSpecificOutput` JSON object with
#       `permissionDecision: "deny"` and a reason naming the offending path,
#       the matched sibling, and the current worktree.
#     - On allow: exit 0 with no stdout, so the tool's regular permission
#       rules still apply.
#
# Known gaps (tolerated — all fail *open*, i.e. false negatives, never
# false positives):
#   - Relative paths like `cd ../../other-tree` are not resolved.
#   - Paths embedded in `KEY=VALUE cmd` or `--flag=/path` are not matched.
#   - Paths inside quoted inline scripts (`python -c '... "/x" ...'`) are
#     not parsed out.
#   - Symlinked paths in tool input that resolve into a sibling — the
#     string compare misses them.
#   - Case-insensitive filesystems with divergent casing between sibling
#     list and tool input.

set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Prefer the tool call's own `cwd` (set per-call by Claude Code, so it reflects
# the subagent's worktree even across `isolation: worktree` boundaries).
# $CLAUDE_PROJECT_DIR is inherited from the parent session and can be stale
# inside a subagent's nested worktree, so it's a last resort.
TOOL_CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
: "${TOOL_CWD:=${CLAUDE_PROJECT_DIR:-$PWD}}"

CURRENT_WT=$(git -C "$TOOL_CWD" rev-parse --show-toplevel 2>/dev/null || true)
if [ -z "$CURRENT_WT" ]; then
  exit 0
fi
CURRENT_WT=$(cd "$CURRENT_WT" 2>/dev/null && pwd -P)
CURRENT_WT="${CURRENT_WT%/}"

SIBLINGS=()
while IFS= read -r line; do
  case "$line" in
    "worktree "*)
      wt="${line#worktree }"
      wt="${wt%/}"
      if [ "$wt" != "$CURRENT_WT" ]; then
        SIBLINGS+=("$wt")
      fi
      ;;
  esac
done < <(git -C "$CURRENT_WT" worktree list --porcelain 2>/dev/null || true)

# Resolve each sibling to its physical path so comparisons line up with
# CURRENT_WT (already pwd -P'd). git's porcelain output is usually physical
# already, but normalize just in case.
for i in "${!SIBLINGS[@]}"; do
  s=$(cd "${SIBLINGS[$i]}" 2>/dev/null && pwd -P) || s="${SIBLINGS[$i]}"
  SIBLINGS[$i]="${s%/}"
done

if [ ${#SIBLINGS[@]} -eq 0 ]; then
  exit 0
fi

candidates=()
case "$TOOL_NAME" in
  Bash)
    COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
    set -f
    # shellcheck disable=SC2086
    for token in $COMMAND; do
      # Strip surrounding quotes so `"/path"` and `'/path'` still match.
      token="${token#[\"\']}"
      token="${token%[\"\']}"
      case "$token" in
        /*) candidates+=("$token") ;;
        \~|\~/*) candidates+=("${HOME}${token#\~}") ;;
      esac
    done
    set +f
    ;;
  Read|Edit|Write|MultiEdit|NotebookEdit)
    p=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
    [ -n "$p" ] && candidates+=("$p")
    ;;
  Grep|Glob)
    p=$(echo "$INPUT" | jq -r '.tool_input.path // empty')
    [ -n "$p" ] && candidates+=("$p")
    ;;
  *)
    exit 0
    ;;
esac

if [ ${#candidates[@]} -eq 0 ]; then
  exit 0
fi

for raw in "${candidates[@]}"; do
  path="${raw/#\~/$HOME}"
  case "$path" in
    /*) ;;
    *) continue ;;
  esac
  path="${path%/}"
  # Pick the longest worktree prefix that contains this path. When the current
  # worktree is nested inside another (e.g. current = /repo/.claude/worktrees/foo,
  # sibling = /repo), both prefix-match paths under current — the longest match
  # wins, so the current worktree correctly overrides the ancestor sibling.
  best_wt=""
  best_kind=""
  if [ "$path" = "$CURRENT_WT" ] || [ "${path#"$CURRENT_WT"/}" != "$path" ]; then
    best_wt="$CURRENT_WT"
    best_kind="current"
  fi
  for wt in "${SIBLINGS[@]}"; do
    if [ "$path" = "$wt" ] || [ "${path#"$wt"/}" != "$path" ]; then
      if [ ${#wt} -gt ${#best_wt} ]; then
        best_wt="$wt"
        best_kind="sibling"
      fi
    fi
  done
  if [ "$best_kind" = "sibling" ]; then
    jq -n \
      --arg path "$raw" \
      --arg wt "$best_wt" \
      --arg current "$CURRENT_WT" \
      '{
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          permissionDecision: "deny",
          permissionDecisionReason: ("Blocked: path " + $path + " is inside sibling worktree " + $wt + ". Current worktree is " + $current + " — stay within it.")
        }
      }'
    exit 0
  fi
done

exit 0
