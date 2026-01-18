# completion_audit: Audit compinit and CLI completions

| Status | Created | Updated |
| --- | --- | --- |
| DRAFT | 2026-01-19 | 2026-01-19 |

Links:

- PR: TBD
- Docs: `scripts/interactive/completion.zsh`, `scripts/_completion/README.md`
- Glossary: `docs/templates/PROGRESS_GLOSSARY.md`

## Addendum

- None

## Goal

- Inventory all completion entrypoints (`compinit`, `fpath` injections, caches) and all first-party completion modules.
- Add clear completion authoring rules + guardrails to prevent regressions (especially spec syntax mixups).
- Fix completion UX issues across first-party CLIs (options, positionals, aliases) and make verification repeatable.

## Acceptance Criteria

- Inventory:
  - This progress file lists every completion entrypoint and first-party completion module (Modules section).
  - Each module lists the commands it completes and relevant runtime dependencies (if any).
- Guardrails:
  - `./tools/check.zsh` passes.
  - A dedicated completion lint/check exists (TBD implementation location) that fails on known footguns, e.g.:
    - `_describe` candidate arrays written in `_arguments` syntax (like `--flag[desc]`).
    - Missing/mismatched `#compdef` / `compdef` coverage for shipped aliases.
- UX correctness (manual smoke):
  - For each CLI listed in Modules:
    - `<cmd><TAB>` suggests expected subcommands/args.
    - `<cmd> --<TAB>` suggests options (no literal descriptions inserted).
    - Aliases listed in `#compdef` behave the same as the primary command.
  - No completion inserts bracketed descriptions as literal text on the command line.

## Scope

- In-scope:
  - Completion bootstrap: `scripts/interactive/completion.zsh` (`compinit`, `fpath`, cache-related zstyles).
  - First-party completion functions under:
    - `scripts/_completion/`
    - `scripts/_features/*/_completion/`
  - Docker completion generation/caching: `scripts/_features/docker/docker-completion.zsh`.
- Out-of-scope:
  - Vendored plugin completions under `plugins/` (upstream-managed; do not restyle).
  - Replacing `fzf-tab` or changing its core matching behavior (only adjust styles when required).
  - Adding completions for new CLIs that are not already shipped in this repo.

## I/O Contract

### Input

- Interactive Zsh session where `scripts/interactive/completion.zsh` runs `compinit`.
- Completion search path (`$fpath`) includes:
  - `scripts/_completion`
  - feature completion dirs such as `scripts/_features/<feature>/_completion`
  - (docker feature) `${ZSH_COMPLETION_CACHE_DIR}/completions` when enabled
- Optional runtime dependencies (module-specific):
  - `docker` for docker-tools related completion
  - `gh` (authenticated) for some git-open completion branches

### Output

- Consistent, correct completion behavior for all first-party CLIs listed in Modules.
- A repeatable verification workflow:
  - `./tools/check.zsh`
  - completion lint/check command (TBD) with clear failure messages

### Intermediate Artifacts

- Compdump: `${ZSH_COMPDUMP}` (or `${ZSH_CACHE_DIR}/.zcompdump` via `compinit -d`).
- Completion cache dir: `${ZSH_COMPLETION_CACHE_DIR}` (compsys cache + docker completion cache).
- Docker generated completions: `${ZSH_COMPLETION_CACHE_DIR}/completions/*` (when docker feature enabled).

## Design / Decisions

### Rationale

- Zsh completion is user-facing and easy to break silently (wrong spec syntax can still "work" but produce bad
  insertions). This audit makes completion behavior reviewable, testable, and harder to regress.

### Risks / Uncertainties

- `_arguments` and `_describe` use different spec formats; mixing them can cause candidates like `--flag[desc]` to be
  inserted literally.
- Some modules depend on external tools (`docker`, `gh`) and must degrade gracefully when missing.
- `fzf-tab` changes how users perceive completion lists; smoke tests must be run with the current repo config.

## Steps (Checklist)

Note: Any unchecked checkbox in Step 0–3 must include a Reason (inline `Reason: ...` or a nested `- Reason: ...`) before close-progress-pr can complete. Step 4 is excluded (post-merge / wrap-up).
Note: For intentionally deferred / not-do items in Step 0–3, use `- [ ] ~~like this~~` and include `Reason:`. Unchecked and unstruck items (e.g. `- [ ] foo`) will block close-progress-pr.

- [ ] Step 0: Inventory and conventions
  - Work Items:
    - [ ] Enumerate completion entrypoints (`compinit`, `fpath`, caches) and record them in this file.
    - [ ] Enumerate first-party completion modules (`#compdef` files) and record them in Modules.
    - [ ] Define completion authoring rules (when to use `_arguments` vs `_describe`; alias handling; option order).
    - [ ] Define a manual smoke-test matrix per CLI (commands + expected behavior).
  - Artifacts:
    - `docs/progress/20260119_cli-completion-audit.md` (this file)
    - `docs/progress/README.md` (index row)
    - Inventory commands (examples):
      - `rg -n "^#compdef\\b" scripts -S`
      - `rg -n "\\bcompinit\\b" scripts -S`
  - Exit Criteria:
    - [ ] Modules list is complete and reviewed.
    - [ ] Scope boundaries and acceptance criteria are agreed.
    - [ ] A clear smoke-test matrix exists (use `rz` / `compinit-reset` when iterating).
- [ ] Step 1: Add guardrails (MVP)
  - Work Items:
    - [ ] Add a completion lint/check that catches common footguns (TBD implementation location).
    - [ ] Fix any failures found in first-party completion files.
  - Artifacts:
    - New check script or `./tools/check.zsh` integration (TBD path).
  - Exit Criteria:
    - [ ] Repo checks pass (`./tools/check.zsh` + completion lint/check).
    - [ ] Known footgun cases are covered by the lint/check.
- [ ] Step 2: Normalize and expand
  - Work Items:
    - [ ] Ensure aliases are consistently covered (via `#compdef`/`compdef` lists or a documented policy).
    - [ ] Review complex completions for correctness and performance (cache where needed).
  - Artifacts:
    - Updated completion modules (TBD list in PR).
  - Exit Criteria:
    - [ ] Completion UX is consistent across all modules listed.
- [ ] Step 3: Validation and evidence
  - Work Items:
    - [ ] Run the smoke-test matrix and record results (in this file or in the PR).
  - Artifacts:
    - Smoke-test results recorded (TBD location; prefer progress file updates).
  - Exit Criteria:
    - [ ] Results recorded and any failures tracked with follow-up tasks.
- [ ] Step 4: Release / wrap-up
  - Work Items:
    - [ ] Update docs (when needed) and archive this progress file.
  - Artifacts:
    - Archived progress file under `docs/progress/archived/`.
  - Exit Criteria:
    - [ ] Status set to DONE and file moved to `docs/progress/archived/`.
    - [ ] `docs/progress/README.md` updated with PR link.

## Modules

- `scripts/interactive/completion.zsh`: Runs `compinit`, sets `fpath`, configures zstyles and fzf-tab, provides `rz`.
- `scripts/_completion/_fzf-tools`: Completion for `fzf-tools`.
- `scripts/_completion/_git-lock`: Completion for `git-lock`.
- `scripts/_completion/_git-open`: Completion for `git-open` (includes `gh`-powered branches).
- `scripts/_completion/_git-scope`: Completion for `git-scope`.
- `scripts/_completion/_git-summary`: Completion for `git-summary`.
- `scripts/_completion/_git-tools`: Completion for `git-tools`, `git-commit-context`, `git-commit-context-json`, `gccj`.
- `scripts/_features/codex-workspace/_completion/_codex-workspace`: Completion for `codex-workspace` and helpers (incl. `cw`).
- `scripts/_features/codex/_completion/_codex-tools`: Completion for `codex-tools` (incl. `cx`).
- `scripts/_features/codex/_completion/_codex-rate-limits`: Completion for `codex-rate-limits` (incl. `crl`).
- `scripts/_features/docker/_completion/_docker-tools`: Completion for `docker-tools` and `docker-aliases`.
- `scripts/_features/docker/docker-completion.zsh`: Generates/caches docker-compose completion before `compinit`.
- `scripts/_features/opencode/_completion/_opencode-tools`: Completion for `opencode-tools` (incl. `oc`).
