# git_open_pr_completion_cache: Cached PR number completion for git-open

| Status | Created | Updated |
| --- | --- | --- |
| DONE | 2025-12-30 | 2025-12-31 |

Links:

- PR: [graysurf/zsh-kit/pull/12](https://github.com/graysurf/zsh-kit/pull/12)
- Docs: `scripts/_completion/_git-open`
- Glossary: `docs/templates/PROGRESS_GLOSSARY.md`

## Goal

- Provide PR number completion for `git-open pr` / `git-open pulls` (and aliases) using `gh`.
- Avoid repeated API calls by caching PR candidates for 60 seconds via compsys cache.

## Acceptance Criteria

- `git-open pr <TAB>` suggests PR numbers (with titles) on GitHub repos with `gh` configured.
- Re-completing within 60 seconds reuses cached candidates (no repeated `gh` calls).
- When `gh` is missing/unauthenticated or outside a Git repo, completion degrades to the existing hint message.

## Scope

- In-scope:
  - `scripts/_completion/_git-open`: PR number candidates with compsys cache + 60s TTL (default; configurable).
  - Completion coverage inventory (commit/branch/tag/remotes/workflows/files) and gap tracking.
  - Follow-up completion improvements after PR merge (see Step 2).
- Out-of-scope:
  - GitLab MR number completion (non-`gh` providers).
  - Non-`gh` issue/PR resolution.

## I/O Contract

### Input

- Inside a Git worktree (`git rev-parse --is-inside-work-tree` passes).
- `gh` installed and authenticated for the current repo (for PR suggestions).
- Completion caching enabled (`zstyle ':completion:*' use-cache on`) for TTL behavior (default: 60s; configurable via `GIT_OPEN_PR_CACHE_TTL_SECONDS`).

### Output

- Completion menu shows PR candidates as `#<number>  -- <title>` (grouped by state when using fzf-tab).
- Falls back to the existing hint message when candidates cannot be computed.

### Intermediate Artifacts

- compsys cache file: `$ZSH_COMPLETION_CACHE_DIR/git-open/prs/<repo_key>` (repo-root path sanitized into a stable key).

## Design / Decisions

### Rationale

- Cache key includes the repo root path (sanitized) under `git-open/prs/` to avoid cross-repo mixing.
- Cache invalidation uses `cache-policy` with a 60s TTL (default), applied only to `*/git-open/prs/*` cache files.
- TTL is configurable via `GIT_OPEN_PR_CACHE_TTL_SECONDS` (default: 60).
- Candidate display format is `#<number>  -- <title>` (works well with `compadd -d` and `#123` input).
- PR candidates are fetched via `gh pr list --state all` and grouped into `OPEN` / `DRAFT` / `MERGED` / `CLOSED` for fzf-tab coloring.
- `gh pr list --limit` is configurable via `GIT_OPEN_PR_LIST_LIMIT` (default: 100).
- Completion routing captures `orig_current`/`orig_words` before `_arguments` because `_arguments` may rewrite `CURRENT`/`words` when entering the `argument-rest` state (breaking subcommand/arg detection if not preserved).

### Risks / Uncertainties

- Risk: PR list may be stale for up to `GIT_OPEN_PR_CACHE_TTL_SECONDS` seconds (default: 60).
  - Mitigation: short TTL by default; re-run completion after TTL to refresh.
- Risk: `gh` may be slow, misconfigured, or unauthenticated.
  - Mitigation: completion suppresses errors and falls back to the existing hint message.

## Steps (Checklist)

- [x] Step 0: Alignment / prerequisites
  - Work Items:
    - [x] Confirm scope: GitHub completion improvements via `gh` (PR now; follow-ups in Step 2), no GitLab support.
    - [x] Confirm UX: show `#<number>  -- <title>` and cache for 60 seconds.
    - [x] Inventory `git-open` completion coverage and gaps (see Step 2).
  - Artifacts:
    - `docs/progress/archived/20251230_git_open_pr_completion_cache.md` (this file)
  - Exit Criteria:
    - [x] Requirements, scope, and acceptance criteria are aligned.

  - Current coverage (already implemented):
    - [x] `git-open commit`: commit hashes.
    - [x] `git-open branch|compare|commits|history`: refs from local branches + remote refs + tags.
    - [x] `git-open tags|releases`: tag names.
    - [x] `git-open repo|default-branch`: remote names.
    - [x] `git-open actions`: workflow files under `.github/workflows/*.y{a,}ml`.
    - [x] `git-open file|blame`: `_files` for path + refs from branches/remotes/tags.

- [x] Step 1: Minimum viable output (MVP)
  - Work Items:
    - [x] Implement PR candidates helper with compsys caching and 60s TTL (default).
    - [x] Wire candidates into `git-open pr` / `git-open pulls` completion (and aliases).
  - Artifacts:
    - `scripts/_completion/_git-open`
  - Exit Criteria:
    - [x] `git-open pr <TAB>` yields PR candidates when `gh` is available.

- [x] Step 2: Expansion / integration
  - Work Items:
    - [x] Preserve original candidate order for `git-open` completion (disable sorting for `:completion:*:git-open:*`).
    - [x] Add fzf-tab PR state grouping and stable state-based colors (no ANSI escapes in `compadd -d`).
    - [x] Show group headers in fzf-tab (state names visible above the candidate list).
    - [x] Keep PR candidates in the original `gh pr list` output order (avoid batching output per group).
    - [x] Add completion development notes (args routing, ANSI pitfalls) to `scripts/_completion/README.md`.
    - [x] Add `compinit-reset` helper for quickly rebuilding compdump during completion development.
    - [x] Make PR list limit configurable via `GIT_OPEN_PR_LIST_LIMIT`.
    - [x] Make PR cache TTL configurable via `GIT_OPEN_PR_CACHE_TTL_SECONDS`.
  - Artifacts:
    - `scripts/_completion/_git-open`
    - `scripts/interactive/completion.zsh`
    - `scripts/_completion/README.md`
  - Exit Criteria:
    - [x] `git-open pr <TAB>` shows state group headers and candidates with stable state colors, and inserts the selected candidate.
    - [x] PR candidate order matches `gh pr list` output order.
    - [x] Completion remains fast (no repeated `gh` calls within the 60s TTL by default).

  - Follow-ups (deferred / out-of-scope for this PR):
    - Issue number completion for `git-open issues [number]` via `gh issue list` (with 60s cache by default).
    - Decide PR/issue insertion token format in interactive shells where `#` may start a comment (`123` vs `#123` vs `\\#123`).
    - Consider `file/blame` path candidates from `git ls-files` (tracked-only) vs `_files` (current behavior).
    - Consider adding commit hashes to other `ref` positions (currently limited to `git-open commit` by design).

- [x] Step 3: Validation / testing
  - Work Items:
    - [x] Run syntax and repo checks.
    - [x] Smoke completion: `git-open branch|compare|commit <TAB>` yields candidates.
  - Artifacts:
    - `zsh -n -- scripts/_completion/_git-open` (pass)
    - `zsh -n -- scripts/interactive/completion.zsh` (pass)
    - `./tools/check.zsh` (pass)
    - `./tools/check.zsh --smoke` (pass)
    - Manual verification: `git-open pr <TAB>` shows grouped/styled candidates and inserts selection (pass)
  - Exit Criteria:
    - [x] Validation commands executed with results recorded (pass).

- [x] Step 4: Release / wrap-up
  - Work Items:
    - [x] Open PR.
    - [x] Merge PR and delete feature branch.
    - [x] Set Status to DONE and move to `docs/progress/archived/`.
  - Artifacts:
    - PR: https://github.com/graysurf/zsh-kit/pull/12
  - Exit Criteria:
    - [x] PR merged; progress archived; index updated.

## Modules

- `scripts/_completion/_git-open`: PR number completion + cache policy.
- `docs/progress/archived/20251230_git_open_pr_completion_cache.md`: tracking doc for this change.
