---
name: upgrade-dependency-review
description: Audit a candidate Python dependency version upgrade across the full version range — surfacing breaking changes, known bugs, security advisories, and new-feature opportunities. Use when the user wants to review a dependency upgrade before or after applying it to pyproject.toml.
---

# Upgrade dependency review

## Trigger

The user wants to review a Python dependency version upgrade. The upgrade may not be applied locally yet (most common — they're evaluating before making the change), or may already be in `pyproject.toml`. Typical phrasing: "review upgrading `<package>` from X to Y", "would bumping `<package>` to Y break anything?", "I just bumped `<package>` — review it".

One dependency per invocation. If multiple upgrades are being considered, run the skill once per dependency.

## Workflow

### 1. Establish the version range

- The user should name a single dependency and a target version `Y`. If either is missing, ask.
- Determine old version `X` from `pyproject.toml`:
  - If `pyproject.toml` still pins the prior version (most common — upgrade not yet applied), that pin is `X`.
  - If `pyproject.toml` already pins `Y` (upgrade already applied), derive `X` from `git diff main...HEAD pyproject.toml`, or ask the user for the prior version.
  - If `pyproject.toml` has no entry for the named dependency, stop and report "dependency not found".
- Record both `X` and `Y`.

### 2. Map codebase usage

- Grep the repo for imports and attribute access of the package (e.g., `import <package>`, `from <package> import ...`, `<package>.<symbol>`). Include submodules.
- Record the concrete APIs the repo uses — class names, decorators, functions, config keys — with `file:line` references. This list is what the breaking-changes analysis will be checked against.
- If the dependency is not imported anywhere (pure transitive, or removed), short-circuit: report "not directly used; upgrade is safe from a usage-site perspective" and skip to Output.

### 3. Delegate release-notes and community research to a subagent

Context protection: this research fetches many pages of release notes and issue threads. Do it in a subagent so the main conversation only sees the summary.

Use `Agent` with `subagent_type: general-purpose`. The subagent prompt must:

- Pass the dependency name, old version `X`, new version `Y`, and the list of APIs this repo uses (from step 2).
- Ask for a structured markdown report covering **every version in the range `(X, Y]`** — not just `Y`. Skipping intermediate versions is the single most common failure mode here; call it out in the prompt.
- Direct the subagent to gather from four sources, in this order of preference:
  1. **Official release notes / changelog** — PyPI project page → the project's own site → GitHub releases → `CHANGELOG.md` in the repo. Covers intentional changes: **breaking changes** (deprecations, removals, renames, behavior shifts) and **new features** (additions, new APIs) introduced in the range.
  2. **Security advisories** — GitHub Security tab / advisories DB for the package's repo, plus any security section in the changelog. Primary source for **security findings**.
  3. **Issue tracker** — GitHub issues on the package's repo filed in the `(X, Y]` window, filtered for `bug`, `regression`, `performance` labels. Primary source for **known bugs** not already covered in the changelog. Include links.
  4. **Community feedback** — search reputable discussion sources (stackoverflow.com, github.com) for recommendations, gotchas, or migration notes tied to versions in the range. Only cite sources the subagent actually fetched; do not invent.
- Require the subagent to return a structured markdown report with explicit sections for: **Breaking changes**, **New features**, **Security advisories**, **Known bugs**, **Community notes**. Routing rules: split changelog entries by type — deprecations, removals, renames, and behavior changes are breaking changes; additions and new APIs are new features; pure bug fixes and internal refactors can be omitted. An issue filed against the new range that is not acknowledged in the changelog is a known bug. CVEs and advisories are security findings regardless of channel. Prefer completeness over brevity — list every notable change, vulnerability, and reported bug, and include source URLs so each finding can be independently verified. If a source could not be fetched (network, auth), the subagent must say so rather than fabricate.

### 4. Analysis

Using the subagent's report plus the usage map from step 2, produce findings in four categories:

1. **Breaking changes** — deliberate API changes documented in the changelog. For each API this repo uses, flag any that were deprecated, renamed, removed, or had signature or behavior changes in `(X, Y]`. Cite the `file:line` that will break.
2. **Known bugs** — unintentional breakage reported in the issue tracker but not called out in the changelog. Surface functional or performance regressions filed against the new range, with issue links. Note whether any observed bug plausibly affects code paths from step 2.
3. **Security advisories** — CVEs or advisories fixed by the upgrade (a reason to upgrade sooner) or newly introduced in the range (a reason to defer or mitigate). Link to the advisory.
4. **New-feature opportunities** — point to specific files/functions in this repo that could be simplified or replaced by capabilities added in `(X, Y]`. Be concrete: name the in-repo symbol, the new API, and the net improvement.

### 5. Emit the report

Single inline markdown block. No file is written. Use these exact headers, in this order:

```
## Dependency review: <package> X → Y

### Usage in repo

### Breaking changes

### Known bugs

### Security advisories

### New-feature opportunities

### Recommended actions
```

Inside each section, choose the clearest form (bullets, short paragraphs, tables) for the findings. If a section has nothing to report, do not omit it — write a canonical line instead: "no breaking changes affect this repo" for Breaking changes, "none reported in range" for Known bugs, "no advisories in range" for Security advisories, "no improvements surfaced in this range" for New-feature opportunities.

## Guardrails

- Analysis, not implementation. Any temporary local change made to verify a finding is fine — installing the new version, writing scratch tests, patching code to probe behavior. The invariant is rollback-ability: every local change must be reverted once the review is done, so the working tree matches its pre-skill state. Keep verification work out of the final report unless it materially changes a conclusion.
- Cover the **full** range `(X, Y]` — do not shortcut by only reading the release notes for `Y`.
- If a source cannot be fetched, say so — never fabricate changelog entries or issue links.
- If the dependency has zero usage sites, short-circuit in step 2. Do not run the research subagent.

## Output

- The inline report from step 5.
- If short-circuited, a one-line reason (dependency not found / not directly used).
