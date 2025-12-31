# Progress Files

## Index

### In progress

| Date | Feature | PR |
| --- | --- | --- |
| - | (none) | - |

### Archived

| Date | Feature | PR |
| --- | --- | --- |
| 2025-12-30 | [git_open_pr_completion_cache](archived/20251230_git_open_pr_completion_cache.md) | [graysurf/zsh-kit/pull/12](https://github.com/graysurf/zsh-kit/pull/12) |
| 2025-12-29 | [git_open_cli](archived/20251229_git_open_cli.md) | [graysurf/zsh-kit/pull/11](https://github.com/graysurf/zsh-kit/pull/11) |
| 2025-12-28 | [fzf_def_docblocks](archived/20251228_fzf_def_docblocks.md) | [graysurf/zsh-kit/pull/10](https://github.com/graysurf/zsh-kit/pull/10) |

## Rule

- File name: `<YYYYMMDD>_<feature_slug>.md`
- Location: `docs/progress/` (IN PROGRESS) / `docs/progress/archived/` (DONE)
- Creation: copy `docs/templates/PROGRESS_TEMPLATE.md`, rename, and replace every placeholder token (the template uses double-square-bracket markers; use `TBD` if unknown)
- Terminology & language policy: follow `docs/templates/PROGRESS_GLOSSARY.md`
- Index: every entry should have a PR link (`TBD` if not created yet)
- PR hygiene:
  - Include a link to the related progress file in the PR description (use a full GitHub blob URL; PR bodies resolve
    relative links under `/pull/`)
  - `Testing` should record the result for each command (pass/failed/skipped), not just the command
- Placeholder check (before commit): `rg -n "\\[\\[.*\\]\\]" docs/progress -S` should return no output
- Archive: when done, set `Status` to `DONE`, remove tentative notes, move to `archived/`, and update the index
