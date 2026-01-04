# scripts/_internal/

This folder contains **internal modules** that are intentionally **not auto-loaded** by the
bootstrap script loader (paths starting with `_` are skipped).

The code here is meant to be sourced explicitly by a caller that needs it.

---

## paths

Files:

- `scripts/_internal/paths.exports.zsh` (exports only)
- `scripts/_internal/paths.init.zsh` (minimal init: ensure cache dir exists)
- `scripts/_internal/paths.zsh` (compat wrapper: exports + init)

Purpose:

- Define core `ZSH_*` path variables (`ZSH_CONFIG_DIR`, `ZSH_SCRIPT_DIR`, `ZSH_CACHE_DIR`, etc.)
  in one place.
- `paths.exports.zsh` is intended to be sourced **very early** (now via `$ZDOTDIR/.zshenv`).
- `paths.init.zsh` is intended to be sourced by interactive/login entrypoints (e.g. `.zshrc`, `.zprofile`).

Notes:

- This module is intentionally under `_internal/` so it is **not auto-loaded** by the bootstrap
  script group loader; callers opt-in via `source`.
- `paths.zsh` remains as a convenience wrapper for scripts that want both exports + init.

## wrappers

File: `scripts/_internal/wrappers.zsh`

Purpose:

- Provide a small generator that creates **executable CLI wrappers** in the cache directory.
- This is needed for subprocess contexts like `fzf --preview`, where zsh functions/aliases from the
  parent shell are not available.

Output location:

- `${ZSH_CACHE_DIR:-$ZDOTDIR/cache}/wrappers/bin`

Generated commands:

- `codex-starship`
- `codex-tools`
- `fzf-tools`
- `git-open`
- `git-scope`
- `git-lock`
- `git-tools`
- `git-summary`

How it is used:

- Interactive shells: `.zshrc` generates wrappers on-demand and prepends the wrappers bin dir to `PATH`.

Notes:

- The wrappers are generated under `cache/` and should remain gitignored (they are runtime artifacts).
- Wrapper scripts source `bootstrap/00-preload.zsh` so helpers like `set_clipboard` are available.
