# _wrappers::zdotdir
# Resolve the repo root used for wrapper generation.
# Usage: _wrappers::zdotdir
_wrappers::zdotdir() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset zdotdir="${ZDOTDIR-}"
  if [[ -n "$zdotdir" ]]; then
    print -r -- "$zdotdir"
    return 0
  fi

  typeset script_dir="${ZSH_SCRIPT_DIR-}"
  if [[ -n "$script_dir" ]]; then
    print -r -- "${script_dir:h}"
    return 0
  fi

  if [[ -d "$HOME/.config/zsh" ]]; then
    print -r -- "$HOME/.config/zsh"
    return 0
  fi

  print -u2 -r -- "_wrappers::zdotdir: ZDOTDIR is not set and no fallback root found"
  return 1
}

# _wrappers::bin_dir
# Print the wrappers bin dir path (`$ZDOTDIR/cache/wrappers/bin`).
# Usage: _wrappers::bin_dir
_wrappers::bin_dir() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset cache_dir="${ZSH_CACHE_DIR-}"
  if [[ -z "$cache_dir" ]]; then
    typeset zdotdir=''
    zdotdir="$(_wrappers::zdotdir)"
    cache_dir="$zdotdir/cache"
  fi

  print -r -- "$cache_dir/wrappers/bin"
  return 0
}

# _wrappers::ensure_path
# Ensure the wrappers bin dir exists and is on PATH.
# Usage: _wrappers::ensure_path
_wrappers::ensure_path() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset bin_dir=''
  bin_dir="$(_wrappers::bin_dir)"

  [[ -d "$bin_dir" ]] || mkdir -p -- "$bin_dir"

  if (( ${path[(Ie)$bin_dir]} == 0 )); then
    path=("$bin_dir" $path)
  fi

  return 0
}

# _wrappers::write_wrapper <name> <entry_fn> <source_relpath...>
# Generate a zsh wrapper script under `$ZDOTDIR/cache/wrappers/bin`.
# Usage: _wrappers::write_wrapper <name> <entry_fn> <source_relpath...>
_wrappers::write_wrapper() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset name="${1-}"
  typeset entry_fn="${2-}"
  shift 2 || true
  typeset -a sources=("$@")

  if [[ -z "$name" || -z "$entry_fn" || ${#sources[@]} -eq 0 ]]; then
    print -u2 -r -- "_wrappers::write_wrapper: Usage: _wrappers::write_wrapper <name> <entry_fn> <source_relpath...>"
    return 2
  fi

  typeset zdotdir_default='' bin_dir='' out=''
  zdotdir_default="$(_wrappers::zdotdir)"
  bin_dir="$(_wrappers::bin_dir)"
  [[ -d "$bin_dir" ]] || mkdir -p -- "$bin_dir"
  out="$bin_dir/$name"

  {
    print -r -- '#!/usr/bin/env -S zsh -f'
    print -r --
    print -r -- "typeset -r ZDOTDIR_DEFAULT='${zdotdir_default}'"
    print -r -- 'if [[ -z "${ZDOTDIR-}" ]]; then'
    print -r -- '  export ZDOTDIR="$ZDOTDIR_DEFAULT"'
    print -r -- 'fi'
    print -r --
    print -r -- 'export ZSH_CONFIG_DIR="${ZSH_CONFIG_DIR:-$ZDOTDIR/config}"'
    print -r -- 'export ZSH_BOOTSTRAP_SCRIPT_DIR="${ZSH_BOOTSTRAP_SCRIPT_DIR:-$ZDOTDIR/bootstrap}"'
    print -r -- 'export ZSH_SCRIPT_DIR="${ZSH_SCRIPT_DIR:-$ZDOTDIR/scripts}"'
    print -r --
    print -r -- 'typeset wrapper_bin="${0:A:h}"'
    print -r -- '[[ -d "$wrapper_bin" ]] && export PATH="$wrapper_bin:$PATH"'
    print -r -- 'typeset wrapper_cache_dir="${wrapper_bin:h:h}"'
    print -r -- 'export ZSH_CACHE_DIR="${ZSH_CACHE_DIR:-$wrapper_cache_dir}"'
    print -r -- 'export ZSH_COMPDUMP="${ZSH_COMPDUMP:-$ZSH_CACHE_DIR/.zcompdump}"'
    print -r --
    print -r -- '[[ -d "$ZSH_CACHE_DIR" ]] || mkdir -p -- "$ZSH_CACHE_DIR"'
    print -r --
    print -r -- 'if [[ -f "$ZSH_BOOTSTRAP_SCRIPT_DIR/00-preload.zsh" ]]; then'
    print -r -- '  source "$ZSH_BOOTSTRAP_SCRIPT_DIR/00-preload.zsh"'
    print -r -- 'fi'
    print -r --
    print -r -- 'typeset -a sources=('
    typeset src=''
    for src in "${sources[@]}"; do
      print -r -- "  \"$src\""
    done
    print -r -- ')'
    print -r -- "typeset src=''"
    print -r -- 'for src in "${sources[@]}"; do'
    print -r -- '  if [[ -f "$ZSH_SCRIPT_DIR/$src" ]]; then'
    print -r -- '    source "$ZSH_SCRIPT_DIR/$src"'
    print -r -- '  else'
    print -r -- '    print -u2 -r -- "❌ missing script: $ZSH_SCRIPT_DIR/$src"'
    print -r -- '    exit 1'
    print -r -- '  fi'
    print -r -- 'done'
    print -r --
    print -r -- "if ! typeset -f $entry_fn >/dev/null 2>&1; then"
    print -r -- "  print -u2 -r -- \"❌ missing function: $entry_fn\""
    print -r -- '  exit 1'
    print -r -- 'fi'
    print -r --
    print -r -- "$entry_fn \"\$@\""
  } >| "$out"

  chmod 755 "$out"
  return 0
}

# _wrappers::ensure_all
# Generate all cached CLI wrapper scripts (for subshells like fzf preview).
# Usage: _wrappers::ensure_all
_wrappers::ensure_all() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  _wrappers::ensure_path

  _wrappers::write_wrapper fzf-tools fzf-tools \
    fzf-tools.zsh

  _wrappers::write_wrapper git-open git-open \
    git/git-open.zsh

  _wrappers::write_wrapper git-scope git-scope \
    git/git-scope.zsh

  _wrappers::write_wrapper git-lock git-lock \
    git/git-lock.zsh

  _wrappers::write_wrapper git-summary git-summary \
    git/git-summary.zsh

  _wrappers::write_wrapper git-tools git-tools \
    git/tools/git-utils.zsh \
    git/tools/git-reset.zsh \
    git/tools/git-branch-cleanup.zsh \
    git/tools/git-commit.zsh \
    git/git-scope.zsh \
    git/git-tools.zsh

  return 0
}
