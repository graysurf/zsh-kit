# Zsh Completion Guide (scripts/_completion)

This document explains how to write and maintain completion scripts in
`scripts/_completion`.

## Scope and Load Order

- Completion files live under `scripts/_completion`.
- `scripts/interactive/completion.zsh` adds this directory to `fpath` and runs `compinit`.
- If a new completion does not show up, rebuild the compdump:
  - `rm -f "$ZSH_COMPDUMP"`
  - `autoload -Uz compinit && compinit -i -d "$ZSH_COMPDUMP"`

## File Naming and Entry Points

- File name: `_tool-name` (e.g., `_git-tools`).
- First line: `#compdef tool-name`.
- Define a function named `_tool-name` and bind with `compdef`.

## Minimal Template

```zsh
#compdef tool-name

_tool-name() {
  emulate -L zsh -o extendedglob

  local context state state_descr
  local -a line
  typeset -A opt_args

  typeset -a subcmds
  subcmds=(
    'foo:Description'
    'bar:Description'
  )

  _arguments -C \
    '(-h --help)'{-h,--help}'[Show help]' \
    '--verbose[Enable verbose output]' \
    '--config=[Path to config file]:config file:_files' \
    '1:command:->subcmds' \
    '*::arg:->args'

  case "${state-}" in
    subcmds)
      _describe -t commands 'tool subcommand' subcmds && return 0
      ;;
    args)
      case "${line[1]-}" in
        foo)
          _arguments '--flag[Description]' && return 0
          ;;
      esac
      ;;
  esac
}

compdef _tool-name tool-name
compdef _tool-name 'tool-name.git'
```

## Completion Flow and State

- Use `_arguments -C` to enable state-based routing and option parsing.
- When using `->state` actions, declare locals `_arguments` will set:
  - `local context state state_descr; local -a line; typeset -A opt_args`
- `words` is the raw command line words (includes options); `CURRENT` is the current word index.
- Subcommand routing:
  - No global options: `words[2]` is usually the subcommand.
  - With global options: use `line[1]` (first non-option arg from `_arguments`) instead of `words[2]`.
- Rule of thumb for list helpers:
  - Has descriptions (`name:desc`) → `_describe`
  - Pure values → `_values`
  - No list, only a hint → `_message`

## Common Pitfall: `_arguments -C` can rewrite `words` / `CURRENT`

When you use `_arguments -C` with a catch-all like `*::arg:->args`, zsh may enter the
`argument-rest` state and **rewrite** `words` / `CURRENT` to represent only the “rest”
segment (not the full command line). This can break argument completion if you keep
using `CURRENT == 3` / `words[2]` after `_arguments`.

Symptoms:

- Subcommand completion works, but `tool subcmd <TAB>` shows no candidates.
- Your helper functions print correct candidates when run manually, but completion is empty.

Fix pattern:

1. Capture the original completion coordinates *before* calling `_arguments`.
2. Resolve `subcmd` from `line[1]` (positional args parsed by `_arguments`) with a fallback to `orig_words[2]`.
3. Trim trailing whitespace (completion can pass words with trailing spaces).
4. Use `orig_current` when checking “which argument position is being completed”.

Example:

```zsh
#compdef tool-name

_tool-name() {
  emulate -L zsh -o extendedglob

  local context state state_descr
  local -a line
  typeset -A opt_args

  typeset -i orig_current="$CURRENT"
  typeset -a orig_words=("${words[@]}")

  _arguments -C \
    '1:command:->subcmds' \
    '*::arg:->args'

  case "${state-}" in
    args)
      local subcmd="${line[1]:-${orig_words[2]-}}"
      subcmd="${subcmd%%[[:space:]]#}"

      if (( orig_current == 3 )); then
        # complete the first arg after subcmd
        :
      fi
      ;;
  esac
}
```

Notes:

- Use `${var:-default}` not `${var-default}` when you want the default for **unset OR empty**.
  - In completion, `line[1]` can be set but empty depending on state.
- The whitespace trim (`%%[[:space:]]#`) is defensive: some completion contexts include trailing spaces
  in `line` / `words` elements.

## Dynamic Candidates (Git Examples)

- Always guard Git queries:
  - `command git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0`
- Use `command git ...` to avoid alias pollution.
- Keep candidates small (e.g., last 20 commits) to avoid slow completion.
- Avoid expensive IO in completion: no network, no large directory scans, no slow commands.
- If dynamic candidates are unavoidable, cache (compsys cache: `_retrieve_cache`/`_store_cache`/`_cache_invalid`, plus a `cache-policy` TTL via `zstyle`).
- Prefer stable outputs:
  - commits: `git log --pretty=format:'%h:%s' -n 20`
  - branches: `git for-each-ref --format='%(refname:short)' refs/heads`
  - remotes: `git remote`

## Options and Flags

- Use `_arguments` for flags and their descriptions.
- Keep `-h/--help` available where possible.
- For nested subcommands, provide a small helper like:
  - `_tool_complete_subcommand_name` and call it in the `args` state.

## Error Handling and Options

- Do NOT set `err_return` or `nounset` in completion functions.
  - Completion helpers often return non-zero as normal control flow.
  - `nounset` can fail on internal completion variables.
- Keep options minimal:
  - Prefer `emulate -L zsh -o extendedglob` (some completion helpers like `_files` rely on `extendedglob`).

## Testing Checklist

- Reload compdump or restart shell after adding a file.
- Confirm the mapping:
  - `print -r -- "${_comps[tool-name]-<none>}"`
- Verify `fpath` includes `scripts/_completion`:
  - `print -l -- $fpath | rg -n -- "/scripts/_completion"`
