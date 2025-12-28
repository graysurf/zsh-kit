# fzf_def_docblocks: Backfill docblocks for fzf-def previews

| Status | Created | Updated |
| --- | --- | --- |
| IN PROGRESS | 2025-12-28 | 2025-12-29 |

Links:

- PR: [graysurf/zsh-kit/pull/10](https://github.com/graysurf/zsh-kit/pull/10)
- Docs: `docs/fzf-def-docs.md`
- Glossary: `docs/templates/PROGRESS_GLOSSARY.md`

## Goal

- Ensure `fzf-tools def` / `fzf-tools function` / `fzf-tools alias` previews consistently surface usable Summary/Usage docblocks.
- Backfill missing or inconsistent function/alias docblocks across first-party `.zsh` files.

## Acceptance Criteria

- Backfill docblocks according to the minimum requirements defined in `docs/fzf-def-docs.md` (A–F / L0–L3) without behavior changes.
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

- updated `.zsh` files with docblocks that follow `docs/fzf-def-docs.md`

### Intermediate Artifacts

- `docs/progress/20251228_fzf_def_docblocks.md` (this file)

## Design / Decisions

### Rationale

- Docblocks are now readily discoverable in `fzf-tools def/function/alias`; standardizing them improves day-to-day ergonomics and helps prevent accidental misuse of high-risk commands.

### Risks / Uncertainties

- Risk: inserting a blank line between a docblock and its definition prevents the docblock from being attached.
  - Mitigation: per `docs/fzf-def-docs.md`, docblocks must be directly adjacent to the definition; use `#` (empty comment lines) for separation within docblocks.
- Risk: overly verbose internal helper docblocks increase preview noise.
  - Mitigation: internal helpers default to L1; only escalate to L2 when behavior is non-obvious or has side effects.

## Steps (Checklist)

- [x] Step 0: Alignment / scaffolding
  - Work Items:
    - [x] Finalize the English guideline document: `docs/fzf-def-docs.md`
    - [x] Add progress templates: `docs/templates/PROGRESS_TEMPLATE.md`, `docs/templates/PROGRESS_GLOSSARY.md`
    - [x] Create the progress file: `docs/progress/20251228_fzf_def_docblocks.md`
    - [x] Add progress system entry point: `docs/progress/README.md`
  - Artifacts:
    - `docs/fzf-def-docs.md`
    - `docs/templates/PROGRESS_TEMPLATE.md`
    - `docs/templates/PROGRESS_GLOSSARY.md`
    - `docs/progress/README.md`
    - `docs/progress/20251228_fzf_def_docblocks.md`
  - Exit Criteria:
    - [x] Requirements, scope, and acceptance criteria are aligned (see this progress file)
    - [x] I/O contract is defined (see I/O Contract)
    - [x] Risks and mitigations are documented (see Risks / Uncertainties)
    - [x] Minimal reproducible verification command is defined: `./tools/check.zsh`

- [ ] Step 1: Docblock backfill (per file)
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
    - [ ] `scripts/chrome-devtools-rdp.zsh`
    - [ ] `scripts/codex.zsh`
    - [ ] `scripts/env.zsh`
    - [ ] `scripts/eza.zsh`
    - [ ] `scripts/fzf-tools.zsh`
    - [ ] `scripts/git/git-lock.zsh`
    - [ ] `scripts/git/git-magic.zsh`
    - [ ] `scripts/git/git-scope.zsh`
    - [ ] `scripts/git/git-summary.zsh`
    - [ ] `scripts/git/git-tools.zsh`
    - [ ] `scripts/git/git.zsh`
    - [ ] `scripts/git/tools/git-branch-cleanup.zsh`
    - [ ] `scripts/git/tools/git-commit.zsh`
    - [ ] `scripts/git/tools/git-remote-open.zsh`
    - [ ] `scripts/git/tools/git-reset.zsh`
    - [ ] `scripts/git/tools/git-utils.zsh`
    - [ ] `scripts/interactive/completion.zsh`
    - [ ] `scripts/interactive/hotkeys.zsh`
    - [ ] `scripts/interactive/plugin-hooks.zsh`
    - [ ] `scripts/interactive/runtime.zsh`
    - [ ] `scripts/macos.zsh`
    - [ ] `scripts/shell-utils.zsh`
    - [ ] `tools/check.zsh`
    - [ ] `tools/random_emoji_cmd.zsh`
  - Artifacts:
    - updated `.zsh` files above
  - Exit Criteria:
    - [ ] Each file has been audited at least once (categorize A–F → backfill required docblocks)
    - [ ] No behavior changes introduced (comments only; `Usage:` text adjusted only when needed for accuracy)

- [ ] Step 2: Optional tooling / reporting
  - Work Items:
    - [ ] (Optional) Add an audit command that prints the baseline and gap list (for PR/review tracking)
  - Artifacts:
    - `tools/` (TBD)
  - Exit Criteria:
    - [ ] A repeatable audit command exists, and this progress file includes the command + output location

- [ ] Step 3: Validation / testing
  - Work Items:
    - [ ] Run repo checks
    - [ ] Spot-check `fzf-tools def` previews manually
  - Artifacts:
    - `./tools/check.zsh` output (capture in PR description or notes)
  - Exit Criteria:
    - [ ] `./tools/check.zsh` (pass)
    - [ ] `fzf-tools def` spot-check confirms docblocks are attached and readable

- [ ] Step 4: Wrap-up
  - Work Items:
    - [ ] Update the `docs/progress/README.md` index (fill in PR link)
    - [ ] Set this progress file `Status` to `DONE` and move it to `docs/progress/archived/`
  - Artifacts:
    - `docs/progress/README.md`
    - `docs/progress/archived/20251228_fzf_def_docblocks.md`
  - Exit Criteria:
    - [ ] This progress file has no placeholders, and all tentative notes are replaced with concrete outcomes
    - [ ] Index and archiving are complete

## Modules

- `docs/fzf-def-docs.md`: docblock guidelines (taxonomy, levels, templates)
- `scripts/fzf-tools.zsh`: docblock extraction + fzf previews
- first-party zsh sources: `.zshrc`, `.zprofile`, `bootstrap/`, `scripts/`, `tools/`
