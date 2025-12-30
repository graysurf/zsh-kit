# git_open_pr_completion_cache: Cached PR number completion for git-open

| Status | Created | Updated |
| --- | --- | --- |
| IN PROGRESS | 2025-12-30 | 2025-12-30 |

Links:

- PR: [graysurf/zsh-kit/pull/12](https://github.com/graysurf/zsh-kit/pull/12)
- Docs: `scripts/_completion/_git-open`
- Glossary: `docs/templates/PROGRESS_GLOSSARY.md`

## Goal

- Provide PR number completion for `git-open pr` / `git-open pulls` (and aliases) using `gh`.
- Avoid repeated API calls by caching PR candidates for 30 seconds via compsys cache.

## Acceptance Criteria

- `git-open pr <TAB>` suggests PR numbers (with titles) on GitHub repos with `gh` configured.
- Re-completing within 30 seconds reuses cached candidates (no repeated `gh` calls).
- When `gh` is missing/unauthenticated or outside a Git repo, completion degrades to the existing hint message.

## Scope

- In-scope:
  - `scripts/_completion/_git-open`: add PR number candidates with compsys cache + 30s TTL.
- Out-of-scope:
  - GitLab MR number completion (non-`gh` providers).
  - Issue number completion.

## I/O Contract

### Input

- Inside a Git worktree (`git rev-parse --is-inside-work-tree` passes).
- `gh` installed and authenticated for the current repo (for PR suggestions).
- Completion caching enabled (`zstyle ':completion:*' use-cache on`) for TTL behavior.

### Output

- Completion candidates for `git-open pr <number>` and `git-open pulls <number>` (and aliases) in the form `#<number>:<title>`.
- Falls back to the existing hint message when candidates cannot be computed.

### Intermediate Artifacts

- compsys cache file: `$ZSH_COMPLETION_CACHE_DIR/git-open/prs/<repo_key>` (repo-root path sanitized into a stable key).

## Design / Decisions

### Rationale

- Cache key includes the repo root path (sanitized) under `git-open/prs/` to avoid cross-repo mixing.
- Cache invalidation uses `cache-policy` with a 30s TTL, applied only to `*/git-open/prs/*` cache files.
- Candidate format is `#<number>:<title>` to work well with `_describe` (and `#123` input).

### Risks / Uncertainties

- Risk: PR list may be stale for up to 30 seconds.
  - Mitigation: short TTL; re-run completion after TTL to refresh.
- Risk: `gh` may be slow, misconfigured, or unauthenticated.
  - Mitigation: completion suppresses errors and falls back to the existing hint message.

## Steps (Checklist)

- [x] Step 0: Alignment / prerequisites
  - Work Items:
    - [x] Confirm scope: PR number completion only (GitHub via `gh`), no GitLab/issue support.
    - [x] Confirm UX: show `#<number>:<title>` and cache for 30 seconds.
  - Artifacts:
    - `docs/progress/20251230_git_open_pr_completion_cache.md` (this file)
  - Exit Criteria:
    - [x] Requirements, scope, and acceptance criteria are aligned.

- [x] Step 1: Minimum viable output (MVP)
  - Work Items:
    - [x] Implement PR candidates helper with compsys caching and 30s TTL.
    - [x] Wire candidates into `git-open pr` / `git-open pulls` completion (and aliases).
  - Artifacts:
    - `scripts/_completion/_git-open`
  - Exit Criteria:
    - [x] `git-open pr <TAB>` yields PR candidates when `gh` is available.

- [ ] Step 2: Expansion / integration
  - Work Items:
    - [ ] Consider issue number completion and/or GitLab support if needed.
  - Artifacts:
    - TBD
  - Exit Criteria:
    - [ ] TBD

- [x] Step 3: Validation / testing
  - Work Items:
    - [x] Run syntax and repo checks.
  - Artifacts:
    - `zsh -n -- scripts/_completion/_git-open` (pass)
    - `./tools/check.zsh` (pass)
  - Exit Criteria:
    - [x] Validation commands executed with results recorded (pass).

- [ ] Step 4: Release / wrap-up
  - Work Items:
    - [x] Open PR.
    - [ ] After merge: set Status to DONE and move to `docs/progress/archived/`.
  - Artifacts:
    - PR: https://github.com/graysurf/zsh-kit/pull/12
  - Exit Criteria:
    - [ ] PR merged; progress archived; index updated.

## Modules

- `scripts/_completion/_git-open`: PR number completion + cache policy.
- `docs/progress/20251230_git_open_pr_completion_cache.md`: tracking doc for this change.
