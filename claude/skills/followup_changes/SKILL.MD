---
name: followup-changes
description: Analyze recent branch changes and complete followup work — types, tests, comments, cleanup, and consistency — scoped strictly to modified code
---

# Followup changes

## Trigger

A branch has recent changes that may need followup work: missing types, test gaps, stale comments, dead code, or inconsistencies introduced by the PR.

## Before Writing Any Code

Analyze the recent changes on the current branch to identify what followup work is actually needed. If no meaningful followup is needed, state why and stop.

## Workflow

Address all applicable items in a single pass. Ordering indicates triage priority, not a constraint to pick only one:

1. **Type annotations** — add or fix types for function signatures, class attributes, and non-obvious variables
2. **Test coverage** — add tests for new code paths, edge cases, and error handling. Update existing tests broken by the changes. Prioritize behavior tests over implementation tests.
3. **Inline comments** — add comments only where the *why* isn't obvious. Remove comments that restate the code or are now stale.
4. **Cleanup** — remove resolved TODOs, dead code exposed by changes, and unused imports.
5. **Consistency** — align naming, patterns, and style with surrounding code and project conventions.

## Scope

Every change MUST trace back to a line added or modified on the branch.

- "Directly affected" means code whose correctness or coherence changed as a result of the PR — e.g., it now fails to type-check, references renamed concepts with stale naming, callers/callees whose contract changed, or tests that no longer reflect actual behavior.
- It does NOT mean code that merely *could be better* independent of the PR.
- If you discover issues outside scope, ignore them.

## Guardrails

- Adhere to @.claude/skills/pytest/SKILL.md for test conventions.
- Run the project's lint and test suite (e.g. `just check`, `make check`, or equivalent) after all changes and ensure it passes completely before finishing.
- Do not improve, refactor, annotate, or test code that was not touched by the PR.

## Anti-patterns to Avoid

- Adding docstrings that restate the function signature
- Over-annotating with complex generic types when simpler types suffice
- Commenting obvious code ("increment counter by 1")
- "Improving" documentation you don't fully understand
- Adding types as `Any` just to silence the type checker
- Cargo-culting docstring formats without useful content

## Output

- Summary of what followup was needed (or why none was needed)
- Build/check outcome
