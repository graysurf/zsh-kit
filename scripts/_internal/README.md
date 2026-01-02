# scripts/_internal/

This folder contains **internal modules** that are intentionally **not auto-loaded** by the
bootstrap script loader (paths starting with `_` are skipped).

The code here is meant to be sourced explicitly by a caller that needs it.

---

## wrappers

File: `scripts/_internal/wrappers.zsh`

Purpose:

- Provide a small generator that creates **executable CLI wrappers** in the cache directory.
- This is needed for subprocess contexts like `fzf --preview`, where zsh functions/aliases from the
  parent shell are not available.

Output location:

- `${ZSH_CACHE_DIR:-$ZDOTDIR/cache}/wrappers/bin`

Generated commands:

- `fzf-tools`
- `git-open`
- `git-scope`
- `git-lock`
- `git-tools`
- `git-summary`

How it is used:

- Login shells: `.zprofile` ensures the wrappers bin dir is on `PATH` and generates wrappers.
- On-demand: `scripts/fzf-tools.zsh` calls `_wrappers::ensure_all` before running fzf flows that rely
  on `git-scope` in `--preview`.

Notes:

- The wrappers are generated under `cache/` and should remain gitignored (they are runtime artifacts).
- Wrapper scripts source `bootstrap/00-preload.zsh` so helpers like `set_clipboard` are available.
