# scripts/ function conventions

This document defines conventions for functions defined under `scripts/`.

Note: `scripts/interactive/**` contains interactive entrypoints (key bindings, plugin hooks, completion init).
These files are allowed to do work at source-time and may depend on an interactive TTY; see "Interactive scripts" below.

This file is intended to be the single source of truth for `scripts/**` conventions; prefer linking here over creating
additional parallel docs.

Scope:

- Zsh modules and helpers in `scripts/**/*.zsh`
  - Interactive entrypoints under `scripts/interactive/**` are a deliberate exception to some "module" rules; see "Interactive scripts" below.
- Zsh completion scripts in `scripts/_completion/_*` (see also `scripts/_completion/README.md`)
- If `.sh` files are added later, treat them as POSIX `sh` or `bash` explicitly (do not assume zsh).

Goals:

- Predictable behavior (options and error handling are not affected by user/global state).
- Each script file is safe to source on its own (minimal implicit dependencies).
- Files do not "accidentally" depend on load order; when an entrypoint must depend on others, that dependency is explicit and documented.

## File roles and dependency rule

### Module files (preferred)

Most `scripts/*.zsh` and `scripts/**/tools/*.zsh` files should be "modules":

- Define functions/aliases only; avoid doing work at source-time.
- Avoid `source`-ing other `scripts/` files at source-time.
- If the module needs shared helpers, either:
  1) Keep the helper in the same file, or
  2) Move shared helpers into a dedicated `*-utils.zsh` module and treat it as a stable dependency, or
  3) Lazy-load the dependency inside the specific function call path (see "Subshells and fzf preview" below).

### Entrypoint/dispatcher files (allowed to depend)

Some files are intentionally "entrypoints" that dispatch to other functions and therefore depend on other modules.
Example patterns include a `*-tools` function/alias that routes subcommands.

Conventions for entrypoints:

- Document required dependencies at the top of the file (which functions/modules must exist).
- Ensure bootstrap/load order makes the dependencies available before the entrypoint is sourced.
- Consider graceful failure when sourced standalone (print a clear error if a required function is missing).

## Interactive scripts (`scripts/interactive/`)

`scripts/interactive/**/*.zsh` contains interactive startup code (prompt, key bindings, plugin hooks, completion init).
These files are loaded as a separate group after the general `scripts/` modules (see `bootstrap/bootstrap.zsh`).

Conventions:

- Source-time work is allowed and expected (e.g. `bindkey`/`zle`, `zstyle`, `compinit`, `setopt`).
- Guard interactive-only features (ZLE, key bindings, `compinit`) with `[[ -o interactive && -t 0 ]]` where relevant.
- Prefer feature detection (`command -v ...`, `(( ${+functions[...]} ))`) and degrade gracefully when optional tools/plugins are missing.
- Keep completion initialization centralized in `scripts/interactive/completion.zsh`; completion definitions live in `scripts/_completion/_*` and follow `scripts/_completion/README.md`.

## Default zsh function template

For most reusable functions (tools, helpers, library functions), use this preamble:

```zsh
myfunc() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset arg1="${1-}" arg2="${2-}"
  shift 2 || true

  # ...
  return 0
}
```

Rationale:

- `emulate -L zsh`: localizes option changes and normalizes behavior across shells/sessions.
- `pipe_fail`: pipeline failures propagate.
- `err_return`: stop early on errors inside the function and return non-zero.
- `nounset`: catch typos and missing inputs early; use `${var-}` / `${var:-default}` for optional values.

## When NOT to use the default template

### Completion functions (`scripts/_completion/_*`)

- Use `emulate -L zsh`.
- Do NOT set `err_return` or `nounset` (non-zero returns are normal control flow in completion).
- Follow `scripts/_completion/README.md`.

### Thin interactive wrappers (builtins, interactive)

For wrappers that intentionally preserve user/global options (e.g. overriding a builtin like `cd`):

- It can be correct to omit `emulate -L zsh` and/or `nounset` to preserve interactive semantics.
- Avoid enabling `err_return` by default (failures in optional UX helpers like `eza`, `bat`, or `fzf` should not abort the
  wrapper nor change the underlying command’s success/failure semantics).
- Wrappers must be quiet in non-interactive contexts: at minimum, gate with `[[ -o interactive ]]` and avoid producing
  extra output when stdout is not a TTY (`! -t 1`).
- If you do use `emulate -L zsh`, be explicit about any options you need to match the user's expectations.

### "Flow control via non-zero return"

If a function deliberately uses non-zero returns as part of normal flow:

- Avoid `err_return`, or wrap the specific command with explicit handling (`if ...; then ...; fi`).

## Naming, scope, and parameters

- User-facing functions: prefer kebab-case (e.g. `git-tools`, `git-open`).
- Internal helpers: prefix with `_` or `__` and keep them file-local by convention.
- Avoid overriding builtins unless intentional; document overrides prominently.

Inside functions:

- Use `typeset`/`local` and always initialize variables.
  - Note: if `typeset_silent` is unset, repeatedly declaring variables without initial values (e.g. `typeset key file`
    inside a loop) can print existing values to stdout (often `key=''` / `file=''`).
    - Prefer `typeset key='' file=''` or declare once outside the loop and only assign inside the loop.
- Assign positional parameters to named locals near the top (avoid repeated `$1`, `$2`, ...).
- Under `nounset`, use `${var-}` when reading optional/unset variables.

## I/O and error handling

- Zsh code: prefer `print -r --` for stdout and `print -u2 -r --` for stderr; avoid `echo`.
- Return values: use `return <code>` in functions; do not `exit` from within a function.
- When using external tools that may be aliased (especially `git`), prefer `command git ...` in non-interactive paths to avoid alias pollution.

## Subshells and fzf preview/execute commands

Some execution paths run in a new process (e.g. `fzf --preview`, `xargs`, `sh -c`, `bash -c`):

- Do not assume zsh builtins/functions exist there.
- Use `printf` instead of `print` in those contexts.
- If you need zsh-only behavior, wrap the command as `zsh -fc '...'`.
- If the subshell needs functions from a module, source it explicitly inside that subshell (guarded by `[[ -f ... ]]`), and prefer locating files via `${ZSH_SCRIPT_DIR-}` / `${ZDOTDIR-}`.

## Zsh string quoting rules

- Literal strings (no `$var` / `$(cmd)` expansion): prefer single quotes, e.g. `typeset homebrew_path=''`.
- When expansion is required: use double quotes and keep them, e.g. `typeset repo_root="$PWD"`, `print -r -- "$msg"`.
- When escape sequences are required: use `$'...'` (e.g., `\n`).
- Auto-fix (empty strings only): `./tools/fix-typeset-empty-string-quotes.zsh --write` normalizes `typeset/local ...=""`
  to `''`.

## Validation checklist

- Syntax check a changed zsh file: `zsh -n -- path/to/file.zsh`
- Repo check (recommended for code changes): `./tools/check.zsh`
- Completion changes: follow `scripts/_completion/README.md` (rebuild compdump as needed)
