# zsh-kit: Open changed files in VSCode

| Status | Created | Updated |
| --- | --- | --- |
| DRAFT | 2026-01-09 | 2026-01-09 |

Links:

- PR: [#17](https://github.com/graysurf/zsh-kit/pull/17)
- Docs: TBD
- Glossary: `docs/templates/PROGRESS_GLOSSARY.md`

## Goal

- Provide a repo-local CLI tool to open a set of recently edited files in VSCode for human review (LLM-friendly).
- Support two input sources with separate functions: explicit file list (default) and git-derived changes (optional).
- When the VSCode CLI is unavailable, behave as a silent no-op (exit 0, no output).

## Acceptance Criteria

- Default (file-list) mode:
  - `./tools/open-changed-files.zsh path/to/a path/to/b` opens both files in a single VSCode instance when `code` exists.
  - When `code` is missing: exits `0` and prints nothing.
  - When no file args are provided, reads newline-delimited file paths from stdin.
  - `./tools/open-changed-files.zsh --dry-run path/to/a path/to/b` prints the planned `code ...` invocations and exits `0`.
  - By default, opens at most 5 files (configurable); extra files are ignored.
- Git mode:
  - `./tools/open-changed-files.zsh --git` opens changed files when in a git work tree:
    - Tracked changed (staged + unstaged)
    - Untracked files
    - Subject to `OPEN_CHANGED_FILES_MAX_FILES` / `--max-files` (default: 5)
  - When not in a git work tree: exits `0` and prints nothing (or `--verbose` explains and exits `0`).
- Interface control:
  - Env `OPEN_CHANGED_FILES_SOURCE` defaults to `list`.
  - CLI flags override env (`--list` / `--git` are mutually exclusive).
  - Env `OPEN_CHANGED_FILES_WORKSPACE_MODE` defaults to `pwd`.
  - CLI flag `--workspace-mode pwd|git` overrides env.
  - Env `OPEN_CHANGED_FILES_MAX_FILES` defaults to `5`; CLI `--max-files <n>` overrides env.
- Safety:
  - Missing/non-existent paths are ignored (or reported only under `--verbose`), and never cause a non-zero exit unless usage is invalid.

## Scope

- In-scope:
  - New first-party tool: `tools/open-changed-files.zsh` (zsh, executable).
  - Two separate implementation functions + thin CLI router.
  - Minimal user docs for the tool (TBD, likely `docs/cli/open-changed-files.md`).
- Out-of-scope:
  - Integrations into interactive hotkeys / fzf-tools UI.
  - Editor support beyond the VSCode CLI (e.g. Cursor, JetBrains).
  - Automatically tracking "LLM edited files" without an explicit input list.

## I/O Contract

### Input

- File-list mode: file paths from CLI args; when no args are provided, read newline-delimited file paths from stdin.
- Git mode: working tree changes derived from `git` (staged + unstaged + untracked; skip deleted paths), then apply `--max-files`.

### Output

- Side effect: open files in VSCode via `code` CLI.
- Workspace strategy (configurable):
  - Default (`OPEN_CHANGED_FILES_WORKSPACE_MODE=pwd`): open everything in a single VSCode window with workspace set to `$PWD`.
  - `OPEN_CHANGED_FILES_WORKSPACE_MODE=git`: for each file, find the nearest git root by searching up to 5 parent directories, group by git root, and open different git roots in different VSCode windows.
  - If no git root is found within 5 parent directories, group the file under `$PWD` as its workspace.
- Chunking strategy:
  - Apply `--max-files` first (default: 5).
  - If `--max-files` is increased, open files per workspace in batches (default: 50) to avoid argv length limits.
- Exit codes:
  - `0`: success or no-op (including VSCode CLI missing).
  - `2`: invalid flags/usage.

### Intermediate Artifacts

- None (optional: `--dry-run`/`--print` for testability; TBD).

## Design / Decisions

### Rationale

- Implement as `tools/open-changed-files.zsh` so it is runnable from a clean checkout and fits existing repo tooling.
- Do not reuse `scripts/fzf-tools.zsh:_fzf_open_in_vscode` because it emits errors and has interactive/session assumptions; implement a purpose-built, silent `code` invocation instead.
- Reuse the existing VSCode grouping idea from `scripts/fzf-tools.zsh`:
  - Find git roots upwards (max depth 5)
  - Open different git roots in different VSCode windows
- Provide `--dry-run`; check for `code` at script start and silently exit `0` if missing.
- Default to opening plain file paths (no `--goto` unless explicitly requested).
- Default to opening at most 5 files to avoid overwhelming the editor and to reduce argv length risk.
- Support stdin input (newline-delimited) when no file args are provided.
- Default to a single VSCode window (`workspace=$PWD`) and allow opt-in git-root grouping via env/flag.

### Risks / Uncertainties

- Pending discussion:
  - Default workspace mode: confirm `pwd` (single window) as the default; keep `git` as an opt-in for fzf-like behavior.
  - VSCode CLI behavior for mixed args: validate that `code -- <workspace_dir> <file1> <file2> ...` reliably opens files in that workspace on macOS/Linux.
  - Batch behavior: confirm that using `--reuse-window` after the first invocation keeps all batches in the same VSCode window.

## Steps (Checklist)

Note: Any unchecked checkbox in Step 0–3 must include a Reason (inline `Reason: ...` or a nested `- Reason: ...`) before close-progress-pr can complete. Step 4 is excluded (post-merge / wrap-up).

- [ ] Step 0: Align CLI and behavior
  - Work Items:
    - [x] Decide the default `--goto` behavior (default: no `--goto`).
    - [x] Decide behavior for non-git-root files (group under `$PWD`).
    - [x] Confirm file-list input interface (CLI args; stdin fallback when no args).
    - [x] Decide default max open files (default: 5).
    - [x] Decide chunking strategy when max-files is increased (batch per workspace).
  - Artifacts:
    - `docs/progress/20260109_open-changed-files-in-vscode.md` (this file)
    - Notes: this thread + reference: `scripts/fzf-tools.zsh:_fzf_open_in_vscode`
  - Exit Criteria:
    - [ ] Requirements, scope, and acceptance criteria are aligned: PR review notes.
    - [ ] Data flow and I/O contract are defined: documented in `docs/cli/open-changed-files.md` (TBD).
    - [ ] Risks and edge cases are enumerated with decisions: see Risks / Uncertainties.
    - [ ] Minimal verification commands are defined: `./tools/check.zsh`, `zsh -n -- tools/open-changed-files.zsh`, and a `--dry-run` example (TBD).
- [ ] Step 1: MVP tool (list + git modes)
  - Work Items:
    - [ ] Add `tools/open-changed-files.zsh` with two internal functions and a CLI router.
    - [ ] Implement silent no-op when `code` is missing.
    - [ ] Implement list mode de-dupe + ignore missing paths.
    - [ ] Implement git mode discovery (staged + unstaged + untracked) when in a git work tree.
  - Artifacts:
    - `tools/open-changed-files.zsh`
    - `docs/cli/open-changed-files.md`
  - Exit Criteria:
    - [ ] Happy path works end-to-end: open two files with one command (manual).
    - [ ] Script is safe when `code` is missing: no output, exit 0 (automatable).
    - [ ] Usage docs skeleton exists: `docs/cli/open-changed-files.md`.
- [ ] Step 2: Integration polish
  - Work Items:
    - [ ] Optional: add wrapper entry to `scripts/_internal/wrappers.zsh` to expose `open-changed-files` command in subshell contexts.
    - [ ] Optional: add `--dry-run`/`--verbose` and document.
  - Artifacts:
    - `scripts/_internal/wrappers.zsh` (optional)
    - Docs updates (TBD)
  - Exit Criteria:
    - [ ] Common branches are covered: empty input, mixed absolute/relative, non-git repo, and git repo.
    - [ ] Compatible with repo conventions (zsh rules, `print`, no `echo`).
    - [ ] Optional flags documented (if added).
- [ ] Step 3: Validation / testing
  - Work Items:
    - [ ] Run repo checks.
    - [ ] Record manual verification notes (opening behavior is not CI-assertable).
  - Artifacts:
    - `./tools/check.zsh` output (pass)
    - Manual test notes in PR
  - Exit Criteria:
    - [ ] `./tools/check.zsh` pass.
    - [ ] `./tools/check.zsh --smoke` pass (if relevant).
    - [ ] Manual tests recorded: with and without `code` present.
- [ ] Step 4: Release / wrap-up
  - Work Items:
    - [ ] Update docs entry points (README / docs index) if needed.
    - [ ] Mark progress as DONE and archive when shipped.
  - Artifacts:
    - Docs index links (TBD)
  - Exit Criteria:
    - [ ] Documentation completed and entry points updated: README / docs links (TBD).
    - [ ] Cleanup completed (set status to DONE, archive, update index): close-progress-pr.

## Modules

- `tools/open-changed-files.zsh`: main CLI entrypoint and the two implementation functions.
- `docs/cli/open-changed-files.md`: user-facing usage and I/O contract.
- `scripts/_internal/wrappers.zsh`: optional wrapper generation for `open-changed-files` in subshell contexts.
