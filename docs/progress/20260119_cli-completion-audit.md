# completion_audit: Audit compinit and CLI completions

| Status | Created | Updated |
| --- | --- | --- |
| IN PROGRESS | 2026-01-19 | 2026-01-19 |

Links:

- Planning PR: [graysurf/zsh-kit/pull/40](https://github.com/graysurf/zsh-kit/pull/40)
- Implementation PR: [graysurf/zsh-kit/pull/41](https://github.com/graysurf/zsh-kit/pull/41)
- Docs: `scripts/interactive/completion.zsh`, `scripts/_completion/README.md`
- Glossary: `docs/templates/PROGRESS_GLOSSARY.md`

## Addendum

- 2026-01-19: Normalized `codex-workspace` to docker-style subcommands (`ls`/`rm`), added `exec` (default `zsh`), and updated completion + docs.

## Goal

- Inventory all completion entrypoints (`compinit`, `fpath` injections, caches) and all first-party completion modules.
- Add clear completion authoring rules + guardrails to prevent regressions (especially spec syntax mixups).
- Fix completion UX issues across first-party CLIs (options, positionals, aliases) and make verification repeatable.

## Acceptance Criteria

- Inventory:
  - This progress file lists every completion entrypoint and first-party completion module (Completion Entrypoints + Modules).
  - Each module lists the commands it completes and relevant runtime dependencies (if any).
- Guardrails:
  - `./tools/check.zsh` passes.
  - A dedicated completion lint/check exists: `./tools/check.zsh --completions` (script: `tools/check-completions.zsh`).
    - Fails on known footguns, e.g.:
      - `_arguments`-style specs (like `--flag[desc]`) outside `_arguments` calls (common `_describe` mixup).
      - `compdef` bindings missing from `#compdef` headers (alias coverage).
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
  - `./tools/check.zsh --completions` (script: `tools/check-completions.zsh`)

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

- [x] Step 0: Inventory and conventions
  - Work Items:
    - [x] Enumerate completion entrypoints (`compinit`, `fpath`, caches) and record them in this file.
    - [x] Enumerate first-party completion modules (`#compdef` files) and record them in Modules.
    - [x] Define completion authoring rules (when to use `_arguments` vs `_describe`; alias handling; option order).
    - [x] Define a manual smoke-test matrix per CLI (commands + expected behavior).
  - Artifacts:
    - `docs/progress/20260119_cli-completion-audit.md` (this file)
    - `docs/progress/README.md` (index row)
    - Inventory commands (examples):
      - `rg -n "^#compdef\\b" scripts -S`
      - `rg -n "\\bcompinit\\b" scripts -S`
  - Exit Criteria:
    - [x] Modules list is complete and reviewed.
    - [x] Scope boundaries and acceptance criteria are agreed.
    - [x] A clear smoke-test matrix exists (use `rz` / `compinit-reset` when iterating).
- [x] Step 1: Add guardrails (MVP)
  - Work Items:
    - [x] Add a completion lint/check that catches common footguns (PR: #41).
    - [x] Fix any failures found in first-party completion files (PR: #41).
  - Artifacts:
    - `tools/check-completions.zsh`
    - `tools/check.zsh` (`--completions`, included in `--all`)
  - Exit Criteria:
    - [x] Repo checks pass: `./tools/check.zsh` + `./tools/check.zsh --completions`.
    - [x] Known footgun cases covered (as of PR #41):
      - Missing `#compdef`
      - `compdef` commands missing from `#compdef`
      - `_arguments`-style specs outside `_arguments`
- [x] Step 2: Normalize and expand
  - Work Items:
    - [x] Ensure aliases are consistently covered (command-level aliases included in `#compdef` / `compdef`).
    - [x] Review complex completions for correctness and performance (cache where needed).
    - Notes:
      - Command-level aliases are covered (e.g. `ft`, `gs`, `gho`, `gcc`).
      - Subcommand shortcut aliases are not explicitly covered yet (e.g. `gop`, `gsc`, `gst`). Reason: they
        pre-fill args and would need wrapper completions or a documented alias-expansion dependency.
  - Artifacts:
    - `scripts/_completion/_fzf-tools` (alias: `ft`)
    - `scripts/_completion/_git-open` (alias: `gho`)
    - `scripts/_completion/_git-tools` (alias: `gcc`)
    - `scripts/_completion/_git-scope` (alias: `gs`)
    - `scripts/_completion/_git-lock` (completes `diff`/`tag` options)
  - Exit Criteria:
    - [x] Completion lint passes (`./tools/check.zsh --completions`).
    - [x] Alias coverage is consistent across the listed Modules.
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

## Completion Entrypoints

- `scripts/_internal/paths.exports.zsh`: exports default `ZSH_COMPDUMP` (`$ZSH_CACHE_DIR/.zcompdump`).
- `scripts/interactive/completion.zsh`:
  - Prepends `scripts/_completion` to `$fpath`.
  - Sets `ZSH_COMPLETION_CACHE_DIR` and configures `zstyle ':completion:*' cache-path`.
  - Runs `compinit -i -d "$ZSH_COMPDUMP"`.
  - Provides `compinit-reset` / `rz`.
- `scripts/_features/*/init.zsh`: prepends feature completion dirs to `$fpath` before `compinit` (`codex`, `codex-workspace`, `docker`, `opencode`).
- `scripts/_features/docker/docker-completion.zsh`: generates cached completions under `${ZSH_COMPLETION_CACHE_DIR}/completions` and prepends that dir to `$fpath` before `compinit`.

## Completion Authoring Rules

- Prefer `_arguments -C` with state routing; resolve the subcommand from `line[1]` (fallback: captured `orig_words[2]`).
- Use `_describe` for `name:desc` pairs; use `_values` for pure values.
- Never use `_arguments` spec strings (like `--flag[desc]`) in `_describe` candidate arrays (they can be inserted literally).
- If a completion file contains explicit `compdef ... <cmd>` bindings, include all those `<cmd>` values in the file's `#compdef` header.

## Manual Smoke Matrix

Notes:

- After changing completion scripts, run `rz` / `compinit-reset` to rebuild the compdump.
- For each CLI below, verify both:
  - `<cmd><TAB>` suggests expected subcommands/args.
  - `<cmd> --<TAB>` suggests options (and never inserts `_arguments` spec text like `--flag[desc]`).

Matrix:

- `fzf-tools` / `ft`: `<cmd><TAB>` lists subcommands; selected completion inserts only the subcommand.
- `git-summary`: `git-summary<TAB>` lists preset ranges; `git-summary <YYYY-MM-DD> <YYYY-MM-DD>` shows date hints.
- `git-lock`: `git-lock<TAB>` lists subcommands; `git-lock unlock<TAB>` suggests cached lock labels; `git-lock diff --<TAB>` suggests `--no-color`; `git-lock tag --<TAB>` suggests `--push` / `-m`.
- `git-scope` / `gs`: `<cmd><TAB>` lists subcommands; `git-scope commit<TAB>` suggests recent commits; `git-scope tracked<TAB>` completes path prefixes.
- `git-open` / `gho`: `<cmd><TAB>` lists subcommands; `<cmd> --<TAB>` suggests `--help` (no bracketed specs inserted).
- `git-tools`: `git-tools<TAB>` lists groups; `git-tools <group><TAB>` lists commands; nested flags complete under `git-tools <group> <cmd> --<TAB>`.
- `git-commit-context` / `gcc`: `<cmd> --<TAB>` suggests options; `*--include=` completes files.
- `codex-workspace` / `cw`: `cw<TAB>` lists subcommands; `cw rm --<TAB>` suggests `--yes`/`--all`; `cw exec<TAB>` suggests workspace containers; `cw rm<TAB>` suggests workspace containers (requires docker).
- `codex-tools` / `cx`: `cx<TAB>` lists subcommands; `cx commit --<TAB>` suggests `--auto-stage` / `--push`.
- `codex-rate-limits` / `crl`: `crl --<TAB>` suggests options; `crl<TAB>` suggests secret file names.
- `docker-tools` / `docker-aliases`: `docker-tools<TAB>` and `docker-aliases<TAB>` list subcommands/options (requires docker feature enabled).
- `docker-compose`: `docker-compose<TAB>` suggests options when completion generation is available (docker feature enabled).
- `opencode-tools` / `oc`: `oc<TAB>` lists subcommands; `oc commit --<TAB>` suggests `--auto-stage` / `--push`.

## Modules

- `scripts/_internal/paths.exports.zsh`: Exports completion-related env defaults (`ZSH_COMPDUMP`).
- `scripts/interactive/completion.zsh`: Runs `compinit`, sets `fpath`, configures zstyles and fzf-tab, provides `rz`.
- `scripts/_completion/_fzf-tools`: Completion for `fzf-tools` (incl. `ft`).
- `scripts/_completion/_git-lock`: Completion for `git-lock`.
- `scripts/_completion/_git-open`: Completion for `git-open` (incl. `gho`; includes `gh`-powered branches).
- `scripts/_completion/_git-scope`: Completion for `git-scope` (incl. `gs`).
- `scripts/_completion/_git-summary`: Completion for `git-summary`.
- `scripts/_completion/_git-tools`: Completion for `git-tools`, `git-commit-context` (incl. `gcc`), `git-commit-context-json` (incl. `gccj`).
- `scripts/_features/codex/init.zsh`: Adds `scripts/_features/codex/_completion` to `$fpath`.
- `scripts/_features/codex-workspace/_completion/_codex-workspace`: Completion for `codex-workspace` and helpers (incl. `cw`).
- `scripts/_features/codex-workspace/init.zsh`: Adds `scripts/_features/codex-workspace/_completion` to `$fpath`.
- `scripts/_features/codex/_completion/_codex-tools`: Completion for `codex-tools` (incl. `cx`).
- `scripts/_features/codex/_completion/_codex-rate-limits`: Completion for `codex-rate-limits` (incl. `crl`).
- `scripts/_features/docker/init.zsh`: Adds `scripts/_features/docker/_completion` to `$fpath`.
- `scripts/_features/docker/_completion/_docker-tools`: Completion for `docker-tools` and `docker-aliases`.
- `scripts/_features/docker/docker-completion.zsh`: Generates/caches docker-compose completion before `compinit`.
- `scripts/_features/opencode/init.zsh`: Adds `scripts/_features/opencode/_completion` to `$fpath`.
- `scripts/_features/opencode/_completion/_opencode-tools`: Completion for `opencode-tools` (incl. `oc`).
- `tools/check-completions.zsh`: Static completion lint/check (invoked via `./tools/check.zsh --completions`).
