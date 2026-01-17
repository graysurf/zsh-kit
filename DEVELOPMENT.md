# Development Guide

This repository is a modular Zsh environment. This document describes the development
conventions and verification workflow for the first-party code in this repo.

## Scope

This repo contains:

- First-party Zsh config and tooling: `.zshrc`, `.zprofile`, `bootstrap/`, `scripts/`, `tools/`
- Vendored third-party plugins: `plugins/` (follow upstream conventions; do not restyle)
- Non-Zsh scripts (`bash`/`sh`/`awk`/etc.): follow the best practices of their target language/shell

Unless stated otherwise, the rules below apply only to first-party Zsh code.

## Where to start

- `scripts/**`: see `scripts/README.md`
- `scripts/_completion/_*`: see `scripts/_completion/README.md`

## First-party Zsh baselines

- Target shell: first-party shell code supports **Zsh only**.
- Shebang (executable Zsh scripts): use `#!/usr/bin/env -S zsh -f`.
  - Library files that are only `source`d typically do not need a shebang.
- Function isolation: start functions with `emulate -L zsh` and explicitly manage options via
  `setopt` / `unsetopt`.
- I/O:
  - Do not use `echo`.
  - Use `print -r --` for stdout and `print -u2 -r --` for stderr.
  - Use `printf` for snippets that may run under `sh`/`bash` (e.g., subshells, `xargs`, `sh -c`).
- Option parsing: prefer `zparseopts` (Zsh) over GNU `getopt`.

## Verification

### Quick checks

- Single file syntax check: `zsh -n -- path/to/file.zsh`
- Repo-wide check (recommended): `./tools/check.zsh`

### Additional checks

- Docblock audit (fzf-def; missing docblocks are failures): `./tools/audit-fzf-def-docblocks.zsh --check`
- Smoke load (isolated ZDOTDIR/cache; any stderr is a failure): `./tools/check.zsh --smoke`
- Bash scripts (only when touching `#!/bin/bash` files; runs ShellCheck if installed): `./tools/check.zsh --bash`
- Semgrep scan (bash/zsh; JSON output under `out/semgrep/`): `./tools/check.zsh --semgrep`
- Everything: `./tools/check.zsh --all`

## Suggested workflow

- After any code change: run `./tools/check.zsh`.
- If you changed functions/aliases/docblocks or added/moved first-party `.zsh` files: also run
  `./tools/audit-fzf-def-docblocks.zsh --check`.
- If you changed bootstrap/startup/plugin loading: also run `./tools/check.zsh --smoke`.
- If you changed any `#!/bin/bash` scripts: also run `./tools/check.zsh --bash`.
- For PRs and change reviews: record each relevant check as `pass`, `failed`, or `not run` (with a short reason).
