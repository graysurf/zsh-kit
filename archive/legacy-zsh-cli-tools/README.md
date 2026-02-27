# Archived: Legacy Zsh CLI tools

This folder retains the historical Zsh implementations for a few CLI tools that used to ship from
this repo, but are now expected to come from **native binaries** (Rust) installed on `PATH`.

## Scope

Archived tools:

- `fzf-tools`
- `git-scope`
- `codex-tools`

What’s archived:

- Zsh scripts (implementations and aliases)
- Zsh completion scripts
- User docs pages
- Legacy tests that exercised the Zsh implementations

## Why

Keeping the old code in-tree (but outside active runtime paths) makes it easy to:

- audit old behavior
- compare output/contracts during migration
- recover patterns without reintroducing maintenance burden

## Layout

This subtree mirrors the original repo layout to preserve navigability and history:

- `docs/cli/*`
- `scripts/**`
- `tests/*.test.zsh`

## Notes

- These files are **not sourced** by default.
- Repo tooling (`./tools/check.zsh`, `./tests/run.zsh`) intentionally ignores `archive/`.
- Some archived docs may reference screenshots under `assets/` (which remain at repo root).
