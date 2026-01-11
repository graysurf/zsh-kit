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

# _wrappers::feature_enabled <name>
# Return 0 if the given feature is enabled in `ZSH_FEATURES`.
# Usage: _wrappers::feature_enabled <name>
_wrappers::feature_enabled() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset name="${1-}"
  [[ -n "$name" ]] || return 1
  name="${name:l}"

  if (( $+functions[zsh_features::enabled] )); then
    zsh_features::enabled "$name"
    return $?
  fi

  typeset zdotdir=''
  zdotdir="$(_wrappers::zdotdir)" || return 1

  typeset features_lib="$zdotdir/scripts/_internal/features.zsh"
  [[ -r "$features_lib" ]] && source "$features_lib"

  if (( $+functions[zsh_features::enabled] )); then
    zsh_features::enabled "$name"
    return $?
  fi

  typeset raw="${ZSH_FEATURES-}"
  raw="${raw:l}"
  [[ -n "$raw" ]] || return 1

  typeset -a parts=(${(s:,:)raw})
  typeset part=''
  for part in "${parts[@]}"; do
    part="${part//[[:space:]]/}"
    [[ "$part" == "$name" ]] && return 0
  done

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

# _wrappers::bundle_wrapper_path
# Print the bundle-wrapper.zsh path (if available).
# Usage: _wrappers::bundle_wrapper_path
_wrappers::bundle_wrapper_path() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset zdotdir=''
  zdotdir="$(_wrappers::zdotdir)" || return 1

  typeset bundler="$zdotdir/tools/bundle-wrapper.zsh"
  [[ -f "$bundler" ]] || return 1
  print -r -- "$bundler"
  return 0

}

# _wrappers::bundle_wrapper <input> <output> [entry_fn] [zdotdir]
# Bundle a wrapper manifest into a standalone script.
# Usage: _wrappers::bundle_wrapper <input> <output> [entry_fn] [zdotdir]
_wrappers::bundle_wrapper() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset input="${1-}"
  typeset output="${2-}"
  typeset entry_fn="${3-}"
  typeset zdotdir="${4-}"

  if [[ -z "$input" || -z "$output" ]]; then
    print -u2 -r -- "_wrappers::bundle_wrapper: Usage: _wrappers::bundle_wrapper <input> <output> [entry_fn] [zdotdir]"
    return 2
  fi
  [[ -f "$input" ]] || { print -u2 -r -- "_wrappers::bundle_wrapper: missing input: $input"; return 1; }

  typeset bundler=''
  bundler="$(_wrappers::bundle_wrapper_path 2>/dev/null)" || bundler=''
  [[ -n "$bundler" ]] || { print -u2 -r -- "_wrappers::bundle_wrapper: bundle-wrapper.zsh not found"; return 1; }

  typeset log=''
  log="$(mktemp 2>/dev/null || true)"
  [[ -n "$log" ]] || log="/tmp/wrappers-bundle.$$.log"

  typeset -a cmd=(zsh -f -- "$bundler" --input "$input" --output "$output")
  [[ -n "$entry_fn" ]] && cmd+=(--entry "$entry_fn")

  if [[ -n "$zdotdir" ]]; then
    if ZDOTDIR="$zdotdir" "${cmd[@]}" 2> "$log"; then
      command rm -f -- "$log" >/dev/null 2>&1 || true
      return 0
    fi
  else
    if "${cmd[@]}" 2> "$log"; then
      command rm -f -- "$log" >/dev/null 2>&1 || true
      return 0
    fi
  fi
  typeset -i rc=$?

  if [[ -f "$log" ]]; then
    command cat "$log" >&2
    command rm -f -- "$log" >/dev/null 2>&1 || true
  fi

  return $rc
}

# _wrappers::needs_update <out> <dep...>
# Return 0 when the output wrapper is missing or older than any dependency.
# Usage: _wrappers::needs_update <out> <dep...>
_wrappers::needs_update() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset out="${1-}"
  shift || true
  typeset -a deps=("$@")

  if [[ -z "$out" || ${#deps[@]} -eq 0 ]]; then
    print -u2 -r -- "_wrappers::needs_update: Usage: _wrappers::needs_update <out> <dep...>"
    return 2
  fi

  [[ -f "$out" ]] || return 0

  typeset dep=''
  for dep in "${deps[@]}"; do
    [[ -n "$dep" ]] || continue
    [[ -f "$dep" ]] || continue
    [[ "$dep" -nt "$out" ]] && return 0
  done

  return 1
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

  typeset bundler=''
  bundler="$(_wrappers::bundle_wrapper_path 2>/dev/null || true)"
  if [[ -n "$bundler" ]]; then
    typeset script_dir="${ZSH_SCRIPT_DIR:-$zdotdir_default/scripts}"
    typeset bootstrap_dir="${ZSH_BOOTSTRAP_SCRIPT_DIR:-$zdotdir_default/bootstrap}"
    typeset wrappers_lib="$script_dir/_internal/wrappers.zsh"
    typeset prelude="$script_dir/_internal/wrappers.bundle-prelude.zsh"
    typeset preload="$bootstrap_dir/00-preload.zsh"

    typeset -a deps=("$wrappers_lib" "$prelude" "$preload")
    deps+=("$bundler")
    typeset src=''
    for src in "${sources[@]}"; do
      deps+=("$script_dir/$src")
    done

    if ! _wrappers::needs_update "$out" "${deps[@]}"; then
      return 0
    fi

    typeset input=''
    input="$(mktemp 2>/dev/null || true)"
    [[ -n "$input" ]] || input="/tmp/wrappers-input.$$.zsh"

    {
      print -r -- '#!/usr/bin/env -S zsh -f'
      print -r -- '# bundle-wrapper manifest (generated)'
      print -r -- 'source "$ZSH_SCRIPT_DIR/_internal/wrappers.bundle-prelude.zsh"'
      print -r -- 'source "$ZSH_BOOTSTRAP_SCRIPT_DIR/00-preload.zsh"'
      print -r --
      print -r -- 'typeset -a sources=('
      for src in "${sources[@]}"; do
        print -r -- "  \"$src\""
      done
      print -r -- ')'
    } >| "$input"

    if _wrappers::bundle_wrapper "$input" "$out" "$entry_fn" "$zdotdir_default"; then
      command rm -f -- "$input" >/dev/null 2>&1 || true
      return 0
    fi

    command rm -f -- "$input" >/dev/null 2>&1 || true
    print -u2 -r -- "_wrappers::write_wrapper: bundling failed; falling back to source-based wrapper ($name)"
  fi

  if ! _wrappers::needs_update "$out" "${ZSH_SCRIPT_DIR:-$zdotdir_default/scripts}/_internal/wrappers.zsh"; then
    return 0
  fi

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

# _wrappers::write_exec_wrapper <name> <exec_relpath>
# Generate a zsh wrapper script under `$ZDOTDIR/cache/wrappers/bin` that execs a repo-local executable.
# Usage: _wrappers::write_exec_wrapper <name> <exec_relpath>
_wrappers::write_exec_wrapper() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset name="${1-}"
  typeset exec_relpath="${2-}"

  if [[ -z "$name" || -z "$exec_relpath" ]]; then
    print -u2 -r -- "_wrappers::write_exec_wrapper: Usage: _wrappers::write_exec_wrapper <name> <exec_relpath>"
    return 2
  fi

  typeset zdotdir_default='' bin_dir='' out=''
  zdotdir_default="$(_wrappers::zdotdir)"
  bin_dir="$(_wrappers::bin_dir)"
  [[ -d "$bin_dir" ]] || mkdir -p -- "$bin_dir"
  out="$bin_dir/$name"

  typeset bundler=''
  bundler="$(_wrappers::bundle_wrapper_path 2>/dev/null || true)"
  if [[ -n "$bundler" && "$exec_relpath" == *.zsh ]]; then
    typeset script_dir="${ZSH_SCRIPT_DIR:-$zdotdir_default/scripts}"
    typeset bootstrap_dir="${ZSH_BOOTSTRAP_SCRIPT_DIR:-$zdotdir_default/bootstrap}"
    typeset wrappers_lib="$script_dir/_internal/wrappers.zsh"
    typeset prelude="$script_dir/_internal/wrappers.bundle-prelude.zsh"
    typeset preload="$bootstrap_dir/00-preload.zsh"
    typeset target="$zdotdir_default/$exec_relpath"

    typeset -a deps=("$wrappers_lib" "$prelude" "$preload")
    deps+=("$bundler")
    [[ -f "$target" ]] && deps+=("$target")

    if ! _wrappers::needs_update "$out" "${deps[@]}"; then
      return 0
    fi

    typeset input=''
    input="$(mktemp 2>/dev/null || true)"
    [[ -n "$input" ]] || input="/tmp/wrappers-input.$$.zsh"

    {
      print -r -- '#!/usr/bin/env -S zsh -f'
      print -r -- '# bundle-wrapper manifest (generated)'
      print -r -- 'source "$ZSH_SCRIPT_DIR/_internal/wrappers.bundle-prelude.zsh"'
      print -r -- 'source "$ZSH_BOOTSTRAP_SCRIPT_DIR/00-preload.zsh"'
      print -r --
      print -r -- "source \"\$ZDOTDIR/$exec_relpath\""
    } >| "$input"

    if _wrappers::bundle_wrapper "$input" "$out" '' "$zdotdir_default"; then
      command rm -f -- "$input" >/dev/null 2>&1 || true
      return 0
    fi

    command rm -f -- "$input" >/dev/null 2>&1 || true
    print -u2 -r -- "_wrappers::write_exec_wrapper: bundling failed; falling back to exec wrapper ($name)"
  fi

  if ! _wrappers::needs_update "$out" "${ZSH_SCRIPT_DIR:-$zdotdir_default/scripts}/_internal/wrappers.zsh"; then
    return 0
  fi

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
    print -r -- "typeset target=\"\$ZDOTDIR/$exec_relpath\""
    print -r -- 'if [[ -x "$target" ]]; then'
    print -r -- '  exec "$target" "$@"'
    print -r -- 'elif [[ -f "$target" ]]; then'
    print -r -- '  exec zsh -f -- "$target" "$@"'
    print -r -- 'else'
    print -r -- '  print -u2 -r -- "❌ missing executable: $target"'
    print -r -- '  exit 1'
    print -r -- 'fi'
  } >| "$out"

  chmod 755 "$out"
  return 0
}

# _wrappers::cleanup_feature_codex
# Remove codex-related wrappers from the wrappers bin dir.
# Usage: _wrappers::cleanup_feature_codex
_wrappers::cleanup_feature_codex() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset bin_dir=''
  bin_dir="$(_wrappers::bin_dir)"
  [[ -d "$bin_dir" ]] || return 0

  command rm -f -- \
    "$bin_dir/codex-starship" \
    "$bin_dir/codex-tools" \
    >/dev/null 2>&1 || true
  return 0
}

# _wrappers::cleanup_feature_opencode
# Remove opencode-related wrappers from the wrappers bin dir.
# Usage: _wrappers::cleanup_feature_opencode
_wrappers::cleanup_feature_opencode() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset bin_dir=''
  bin_dir="$(_wrappers::bin_dir)"
  [[ -d "$bin_dir" ]] || return 0

  command rm -f -- \
    "$bin_dir/opencode-tools" \
    >/dev/null 2>&1 || true
  return 0
}

# _wrappers::ensure_core
# Generate cached CLI wrapper scripts for core commands.
# Usage: _wrappers::ensure_core
_wrappers::ensure_core() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  _wrappers::ensure_path

  _wrappers::write_wrapper fzf-tools fzf-tools \
    git/tools/git-utils.zsh \
    git/git-scope.zsh \
    fzf-tools.zsh

  _wrappers::write_wrapper git-open git-open \
    git/git-open.zsh

  _wrappers::write_wrapper git-scope git-scope \
    git/git-scope.zsh

  _wrappers::write_wrapper git-lock git-lock \
    git/git-lock.zsh

  _wrappers::write_wrapper git-summary git-summary \
    git/git-summary.zsh

  _wrappers::write_exec_wrapper open-changed-files \
    tools/open-changed-files.zsh

  _wrappers::write_wrapper git-tools git-tools \
    git/tools/git-utils.zsh \
    git/tools/git-reset.zsh \
    git/tools/git-branch-cleanup.zsh \
    git/tools/git-commit.zsh \
    git/git-scope.zsh \
    git/git-tools.zsh

  return 0
}

# _wrappers::ensure_feature_codex
# Generate cached CLI wrapper scripts for the `codex` feature.
# Usage: _wrappers::ensure_feature_codex
_wrappers::ensure_feature_codex() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  _wrappers::write_wrapper codex-starship codex-starship \
    _features/codex/codex-starship.zsh

  _wrappers::write_wrapper codex-tools codex-tools \
    _features/codex/codex-tools.zsh

  return 0
}

# _wrappers::ensure_feature_opencode
# Generate cached CLI wrapper scripts for the `opencode` feature.
# Usage: _wrappers::ensure_feature_opencode
_wrappers::ensure_feature_opencode() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  _wrappers::write_wrapper opencode-tools opencode-tools \
    _features/opencode/opencode-tools.zsh

  return 0
}

# _wrappers::ensure_all
# Generate cached CLI wrapper scripts for all enabled features.
# Usage: _wrappers::ensure_all
_wrappers::ensure_all() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  _wrappers::ensure_core

  if _wrappers::feature_enabled codex; then
    _wrappers::ensure_feature_codex
  else
    _wrappers::cleanup_feature_codex
  fi

  if _wrappers::feature_enabled opencode; then
    _wrappers::ensure_feature_opencode
  else
    _wrappers::cleanup_feature_opencode
  fi

  return 0
}
