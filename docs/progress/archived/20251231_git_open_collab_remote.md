# git_open_collab_remote: Prefer a collab remote for git-open collaboration pages

| Status | Created | Updated |
| --- | --- | --- |
| DONE | 2025-12-31 | 2025-12-31 |

Links:

- PR: [graysurf/zsh-kit/pull/13](https://github.com/graysurf/zsh-kit/pull/13)
- Docs: `docs/cli/git-open.md`
- Glossary: `docs/templates/PROGRESS_GLOSSARY.md`

## Goal

- Allow `git-open` to prefer a configured “collab remote” (e.g. `origin`) for collaboration/list pages.
- Keep “content” pages following the current branch upstream (`@{u}`) behavior.

## Acceptance Criteria

- When `GIT_OPEN_COLLAB_REMOTE` is set to an existing git remote (e.g. `origin`):
  - `git-open pr` (no number), `git-open pulls`, `git-open issues`, `git-open actions`, `git-open releases` open URLs under that remote’s repository.
  - `git-open pr <number>` opens the PR under that remote’s repository.
  - “Content” commands (e.g. `commit`, `file`, `blame`, `compare`) keep their existing behavior.
- When `GIT_OPEN_COLLAB_REMOTE` is unset or points to a missing remote, behavior remains unchanged.

## Scope

- In-scope:
  - `scripts/git/git-open.zsh`: add `GIT_OPEN_COLLAB_REMOTE` support and route collab subcommands through it.
  - `docs/cli/git-open.md`: document `GIT_OPEN_COLLAB_REMOTE` (usage + fallback behavior).
- Out-of-scope:
  - Adding a new CLI flag (e.g. `git-open --remote ...`) for this feature.
  - Provider-specific “collab remote” logic beyond what `git-open` already supports.

## I/O Contract

### Input

- Inside a Git worktree.
- Optional env var: `GIT_OPEN_COLLAB_REMOTE=<remote>` (e.g. `origin`).
- The named remote exists (`git remote get-url <remote>` succeeds) to take effect.

### Output

- The opened URL for collaboration/list pages targets the collab remote repository when configured.
- Otherwise, `git-open` falls back to its existing upstream-tracking behavior.

### Intermediate Artifacts

- None.

## Design / Decisions

### Rationale

- Collaboration pages (PRs/issues/actions/releases) are typically shared at the repository level; a stable “collab remote”
  reduces surprises when local branches track different remotes.

### Risks / Uncertainties

- Risk: The configured remote may not exist in some repos (e.g. fresh clones).
  - Mitigation: graceful fallback to the current behavior.

## Steps (Checklist)

- [x] Step 0: Alignment / prerequisites
  - Work Items:
    - [x] Confirm env-based approach: `GIT_OPEN_COLLAB_REMOTE` (no new CLI flags for now).
    - [x] Confirm routing: collaboration/list pages prefer collab remote; content pages remain unchanged.
  - Artifacts:
    - `docs/progress/20251231_git_open_collab_remote.md` (this file)
  - Exit Criteria:
    - [x] Requirements, scope, and acceptance criteria are aligned.

- [x] Step 1: Minimum viable output (MVP)
  - Work Items:
    - [x] Implement collab context resolution from `GIT_OPEN_COLLAB_REMOTE`.
    - [x] Route `pr/pulls/issues/actions/releases` through collab context (including `pr` without number).
  - Artifacts:
    - `scripts/git/git-open.zsh`
    - `docs/cli/git-open.md`
  - Exit Criteria:
    - [x] `GIT_OPEN_COLLAB_REMOTE=origin git-open pulls` opens the correct repository URL.
      - Verified in `~/Project/graysurf/context7`: opened `https://github.com/upstash/context7/pulls`

- [x] Step 2: Expansion / integration
  - Work Items:
    - [x] Treat `tags` as a collab page (align with `releases`); keep `commits` following upstream.
  - Artifacts:
    - `docs/cli/git-open.md`
  - Exit Criteria:
    - [x] Coverage is explicitly documented (which subcommands are collab vs content).
  - Addendum (2025-12-31)
    - Follow-up decision: route `git-open tags` via `GIT_OPEN_COLLAB_REMOTE` as well (repo-level list page, aligns with `releases`).
    - Implementation: `_git_open_tags` now uses `_git_open_collab_context` (same routing as `releases`), and docs/usage notes list `tags` as a collab page.

- [x] Step 3: Validation / testing
  - Work Items:
    - [x] Run repo checks.
  - Artifacts:
    - `zsh -n -- scripts/git/git-open.zsh` (pass)
    - `./tools/check.zsh` (pass)
  - Exit Criteria:
    - [x] Validation commands executed with results recorded.

- [x] Step 4: Release / wrap-up
  - Work Items:
    - [x] Open PR.
    - [x] Set Status to DONE and move this file to `docs/progress/archived/`.
  - Artifacts:
    - PR: https://github.com/graysurf/zsh-kit/pull/13
  - Exit Criteria:
    - [x] Progress archived and index updated.

## Modules

- `scripts/git/git-open.zsh`: CLI entrypoint; adds collab-remote routing for selected subcommands.
- `docs/cli/git-open.md`: documents the env var and behavior.
