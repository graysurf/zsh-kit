# fzf_def_docblocks: Backfill docblocks for fzf-def previews

| Status | Created | Updated |
| --- | --- | --- |
| DONE | 2025-12-28 | 2025-12-30 |

Links:

- PR: [graysurf/zsh-kit/pull/10](https://github.com/graysurf/zsh-kit/pull/10)
- Docs: `docs/guides/fzf-def-docs.md`
- Glossary: `docs/templates/PROGRESS_GLOSSARY.md`

## Goal

- Ensure `fzf-tools def` / `fzf-tools function` / `fzf-tools alias` previews consistently surface usable Summary/Usage docblocks.
- Backfill missing or inconsistent function/alias docblocks across first-party `.zsh` files.

## Acceptance Criteria

- Backfill docblocks according to the minimum requirements defined in `docs/guides/fzf-def-docs.md` (A–F / L0–L3) without behavior changes.
- `./tools/check.zsh` (pass)
- `rg -n "\\[\\[.*\\]\\]" docs/progress -S` returns no output (no unreplaced placeholders in progress files)
- Spot-check: `fzf-tools def` previews cover representative user-facing commands, dispatchers, and high-risk aliases/functions.

## Scope

- In-scope:
  - Docblocks/comments only (minor `Usage:` text adjustments are allowed to match actual argument parsing)
  - Reposition docblocks to satisfy capture rules (ensure adjacency; avoid blank-line breaks)
  - Minimal updates to `docs/` when needed for docblock usage guidance
- Out-of-scope:
  - Behavior changes, refactors, moving files, or renaming functions/aliases
  - Redesigning tool interfaces or adding features

## I/O Contract

### Input

- first-party `.zsh` files (see Step 1)

### Output

- updated `.zsh` files with docblocks that follow `docs/guides/fzf-def-docs.md`

### Intermediate Artifacts

- `docs/progress/archived/20251228_fzf_def_docblocks.md` (this file)

## Design / Decisions

### Rationale

- Docblocks are now readily discoverable in `fzf-tools def/function/alias`; standardizing them improves day-to-day ergonomics and helps prevent accidental misuse of high-risk commands.

### Risks / Uncertainties

- Risk: inserting a blank line between a docblock and its definition prevents the docblock from being attached.
  - Mitigation: per `docs/guides/fzf-def-docs.md`, docblocks must be directly adjacent to the definition; use `#` (empty comment lines) for separation within docblocks.
- Risk: overly verbose internal helper docblocks increase preview noise.
  - Mitigation: internal helpers default to L1; only escalate to L2 when behavior is non-obvious or has side effects.

## Steps (Checklist)

- [x] Step 0: Alignment / scaffolding
  - Work Items:
    - [x] Finalize the English guideline document: `docs/guides/fzf-def-docs.md`
    - [x] Add progress templates: `docs/templates/PROGRESS_TEMPLATE.md`, `docs/templates/PROGRESS_GLOSSARY.md`
    - [x] Create the progress file: `docs/progress/20251228_fzf_def_docblocks.md`
    - [x] Add progress system entry point: `docs/progress/README.md`
  - Artifacts:
    - `docs/guides/fzf-def-docs.md`
    - `docs/templates/PROGRESS_TEMPLATE.md`
    - `docs/templates/PROGRESS_GLOSSARY.md`
    - `docs/progress/README.md`
    - `docs/progress/archived/20251228_fzf_def_docblocks.md`
  - Exit Criteria:
    - [x] Requirements, scope, and acceptance criteria are aligned (see this progress file)
    - [x] I/O contract is defined (see I/O Contract)
    - [x] Risks and mitigations are documented (see Risks / Uncertainties)
    - [x] Minimal reproducible verification command is defined: `./tools/check.zsh`

- [x] Step 1: Docblock backfill (per file)
  - Work Items:
    - [x] `.zshrc`
    - [x] `.zprofile`
    - [x] `bootstrap/00-preload.zsh`
    - [x] `bootstrap/bootstrap.zsh`
    - [x] `bootstrap/define-loaders.zsh`
    - [x] `bootstrap/install-tools.zsh`
    - [x] `bootstrap/plugin_fetcher.zsh`
    - [x] `bootstrap/plugins.zsh`
    - [x] `bootstrap/quote-init.zsh`
    - [x] `bootstrap/weather.zsh`
    - [x] `scripts/chrome-devtools-rdp.zsh`
    - [x] `scripts/codex.zsh`
    - [x] `scripts/env.zsh`
    - [x] `scripts/eza.zsh`
    - [x] `scripts/fzf-tools.zsh`
    - [x] `scripts/git/git-lock.zsh`
    - [x] `scripts/git/git-magic.zsh`
    - [x] `scripts/git/git-scope.zsh`
    - [x] `scripts/git/git-summary.zsh`
    - [x] `scripts/git/git-tools.zsh`
    - [x] `scripts/git/git.zsh`
    - [x] `scripts/git/tools/git-branch-cleanup.zsh`
    - [x] `scripts/git/tools/git-commit.zsh`
    - [x] `scripts/git/git-open.zsh`
    - [x] `scripts/git/tools/git-reset.zsh`
    - [x] `scripts/git/tools/git-utils.zsh`
    - [x] `scripts/interactive/completion.zsh`
    - [x] `scripts/interactive/hotkeys.zsh`
    - [x] `scripts/interactive/plugin-hooks.zsh`
    - [x] `scripts/interactive/runtime.zsh`
    - [x] `scripts/macos.zsh`
    - [x] `scripts/shell-utils.zsh`
    - [x] `tools/check.zsh`
    - [x] `tools/random_emoji_cmd.zsh`
  - Artifacts:
    - updated `.zsh` files above
  - Exit Criteria:
    - [x] Each file has been audited at least once (categorize A–F → backfill required docblocks)
    - [x] No behavior changes introduced (docblock work only; comments/whitespace; `Usage:` text adjusted only when needed for accuracy)
  - Verification:
    - `./tools/audit-fzf-def-docblocks.zsh --check` (no gaps)
    - `./tools/check.zsh --smoke` (pass)

- [x] Step 2: Optional tooling / reporting
  - Work Items:
    - [x] Add an audit command that prints the baseline and gap list (for PR/review tracking)
    - [x] Add a GitHub Actions step that runs the audit and uploads the report as an artifact
    - [x] Add fixture-based tests to verify the audit detects gaps (missing/disabled docblocks)
  - Artifacts:
    - `tools/audit-fzf-def-docblocks.zsh`
    - default output: `$ZSH_CACHE_DIR/fzf-def-docblocks-audit.txt` (override via `FZF_DEF_DOC_AUDIT_OUT`)
    - `.github/workflows/check.yml` (CI runs the audit and uploads `fzf-def-docblocks-audit`)
    - `tests/fixtures/audit-fzf-def-docblocks/` (known-good and known-bad cases)
    - `tests/run.zsh` and `tests/audit-fzf-def-docblocks.test.zsh`
  - Exit Criteria:
    - [x] A repeatable audit command exists, and this progress file includes the command + output location
    - [x] CI runs the audit and publishes `cache/fzf-def-docblocks-audit.txt` as `fzf-def-docblocks-audit`
  - Command:
    - `./tools/audit-fzf-def-docblocks.zsh`
    - `./tools/audit-fzf-def-docblocks.zsh --check` (fail if gaps exist)
    - `zsh -f ./tests/run.zsh`

- [x] Step 3: Validation / testing
  - Work Items:
    - [x] Run repo checks
    - [x] Spot-check `fzf-tools def` previews manually
  - Artifacts:
    - `./tools/check.zsh` output (capture in PR description or notes)
    - `cache/fzf-def-docblocks-spotcheck.txt` (local spot-check snapshot; ignored by git)
  - Exit Criteria:
    - [x] `./tools/check.zsh --all` (pass)
    - [x] `fzf-tools def` spot-check confirms docblocks are attached and readable
  - Verification:
    - `./tools/check.zsh --all`
    - `zsh -f ./tests/run.zsh`

- [x] Step 4: Wrap-up
  - Work Items:
    - [x] Update the `docs/progress/README.md` index (fill in PR link)
    - [x] Set this progress file `Status` to `DONE` and move it to `docs/progress/archived/`
  - Artifacts:
    - `docs/progress/README.md`
    - `docs/progress/archived/20251228_fzf_def_docblocks.md`
  - Exit Criteria:
    - [x] This progress file has no placeholders, and all tentative notes are replaced with concrete outcomes
    - [x] Index and archiving are complete
  - Verification:
    - `rg -n "\\[\\[.*\\]\\]" docs/progress -S` (no output)

## Modules

- `docs/guides/fzf-def-docs.md`: docblock guidelines (taxonomy, levels, templates)
- `scripts/fzf-tools.zsh`: docblock extraction + fzf previews
- first-party zsh sources: `.zshrc`, `.zprofile`, `bootstrap/`, `scripts/`, `tools/`
