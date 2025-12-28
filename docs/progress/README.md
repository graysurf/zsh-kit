# Progress Files

## Index

### In progress

| Date | Feature | PR |
| --- | --- | --- |
| 2025-12-28 | [fzf_def_docblocks](20251228_fzf_def_docblocks.md) | [graysurf/zsh-kit/pull/10](https://github.com/graysurf/zsh-kit/pull/10) |

### Archived

| Date | Feature | PR |
| --- | --- | --- |
| - | - | - |

## Rule

- File name: `<YYYYMMDD>_<feature_slug>.md`
- Location: `docs/progress/` (in progress) / `docs/progress/archived/` (done)
- Creation: copy `docs/templates/PROGRESS_TEMPLATE.md`, rename, and replace every placeholder token (the template uses double-square-bracket markers; use `TBD` if unknown)
- Terminology & language policy: follow `docs/templates/PROGRESS_GLOSSARY.md`
- Index: every entry should have a PR link (`TBD` if not created yet)
- PR hygiene: `Testing` should record the result for each command (pass/failed/skipped), not just the command
- Placeholder check (before commit): `rg -n "\\[\\[.*\\]\\]" docs/progress -S` should return no output
- Archive: when done, set `Status` to `done`, remove tentative notes, move to `archived/`, and update the index
