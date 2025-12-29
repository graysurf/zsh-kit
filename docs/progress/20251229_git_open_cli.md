# git_open_cli: Consolidate git-open into a single CLI

| Status | Created | Updated |
| --- | --- | --- |
| IN PROGRESS | 2025-12-29 | 2025-12-30 |

Links:

- PR: [graysurf/zsh-kit/pull/11](https://github.com/graysurf/zsh-kit/pull/11)
- Docs: `scripts/git/git-open.zsh`
- Glossary: `docs/templates/PROGRESS_GLOSSARY.md`

## Goal

- Replace `git-open-*` commands with a single `git-open <subcommand>` CLI.
- Remove `git-tools open` now that `git-open` is the dedicated CLI.

## Acceptance Criteria

- `git-open` (no args) opens the repo page (same behavior as before).
- `git-open` subcommands work as expected:
  - `repo [remote]`, `branch [ref]`, `default-branch [remote]`, `commit [ref]`
  - `compare [base] [head]`, `pr [number]`, `pulls [number]`, `issues [number]`
  - `actions [workflow]`, `releases [tag]`, `tags [tag]` (opens release page)
  - `commits [ref]`, `file <path> [ref]`, `blame <path> [ref]`
- `git-tools` no longer exposes an `open` group (use `git-open ...`).
- No remaining references to `git-open-branch`, `git-open-default-branch`, `git-open-commit`, or `git-push-open`.
- Repo checks pass: `./tools/check.zsh` (pass).

## Scope

- In-scope:
  - Refactor `git-open` into a dispatcher CLI with shared internal helpers.
  - Add common open targets (compare, PR, lists, file view, blame, history).
  - Update aliases and callers to use the new subcommand form.
  - Update help text/docs to match the new CLI.
- Out-of-scope:
  - Provider-specific deep links beyond common pages (settings, wiki, security, etc.).
  - Preserving deprecated command aliases for `git-open-*`.

## I/O Contract

### Input

- Current git repo with an upstream remote (fallback: `origin`).

### Output

- Opens a browser URL via `open` (macOS) or `xdg-open`.

### Intermediate Artifacts

- None.

## Design / Decisions

### Rationale

- A single `git-open` CLI reduces surface area and makes discovery/usage consistent.
- Keep `git-tools` focused on non-open utilities; `git-open` is its own CLI.

### Risks / Uncertainties

- Removal of `git-open-*` may break muscle memory; mitigated by updating aliases (`goc/gob/god`) and callers.
- Provider detection is heuristic (github/gitlab/generic) and may not match all self-hosted setups.
- `actions` is GitHub-only; `pr` prefers `gh` when available (fallback opens compare/new PR page).
- `tags <tag>` is defined as “open release page for tag”; use `git-open branch <tag>` for tag tree.

## Steps (Checklist)

- [x] Step 0: Alignment / prerequisites
  - Work Items:
    - [x] Confirm desired `git-open` subcommands and remove old commands.
    - [x] Confirm `git-tools open` should drop upstream/normalize-url/push-open.
  - Artifacts:
    - `docs/progress/20251229_git_open_cli.md` (this file)
  - Exit Criteria:
    - [x] Requirements, scope, and acceptance criteria are aligned.
    - [x] Minimal verification commands are defined (`./tools/check.zsh`).
- [x] Step 1: Minimum viable output (MVP)
  - Work Items:
    - [x] Implement `git-open` dispatcher and shared helpers.
    - [x] Remove legacy `git-open-*` functions.
  - Artifacts:
    - `scripts/git/git-open.zsh`
  - Exit Criteria:
    - [x] `git-open` and key subcommands run end-to-end.
- [x] Step 2: Expansion / integration
  - Work Items:
    - [x] Update aliases/callers/docs to use `git-open <subcommand>`.
    - [x] Remove `git-tools open` group and related completion/docs.
    - [x] Add common open targets (`compare`, `pr`, `pulls`, `issues`, etc.).
    - [x] Allow optional target args (remote/tag/number/workflow) where it improves UX.
    - [x] Add `git-open` completion.
  - Artifacts:
    - `scripts/git/git-tools.zsh`
    - `scripts/_completion/_git-tools`
    - `scripts/_completion/_git-open`
    - `scripts/git/git.zsh`
    - `scripts/git/git-magic.zsh`
    - `docs/git-tools.md`
    - `scripts/README.md`
  - Exit Criteria:
    - [x] No remaining references to legacy command names.
- [x] Step 3: Validation / testing
  - Work Items:
    - [x] Run repo checks.
  - Artifacts:
    - `./tools/check.zsh` (pass)
  - Exit Criteria:
    - [x] Validation and test commands executed with results recorded: `./tools/check.zsh` (pass).
- [ ] Step 4: Release / wrap-up
  - Work Items:
    - [x] Open PR and collect review feedback.
    - [ ] After merge: set Status to DONE and move to `docs/progress/archived/`.
  - Artifacts:
    - PR: https://github.com/graysurf/zsh-kit/pull/11
  - Exit Criteria:
    - [ ] Documentation completed and entry points updated.
    - [ ] Cleanup completed (status DONE; archived; index updated).

## Modules

- `scripts/git/git-open.zsh`: `git-open` CLI implementation and shared helpers.
- `scripts/_completion/_git-open`: completion for `git-open`.
- `scripts/git/git-tools.zsh`: aliases and `git-tools` dispatcher.
