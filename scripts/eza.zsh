# ───────────────────────────────────────────────────────
# Aliases and Unalias
# ────────────────────────────────────────────────────────
if command -v safe_unalias >/dev/null; then
  safe_unalias \
    ll lx lt llt lt2 lt3 lt5 \
    llt2 llt3 llt5 \
    lxt lxt2 lxt3 lxt5
fi

__eza_with_optional_depth() {
  local -a base_args level_flag
  local first_arg

  base_args=()
  while (( $# > 0 )); do
    if [[ "${1-}" == -- ]]; then
      shift
      break
    fi
    base_args+=("$1")
    shift
  done

  level_flag=()
  first_arg="${1-}"
  if [[ "$first_arg" =~ ^[0-9]+$ ]]; then
    level_flag=(-L "$first_arg")
    shift
  fi

  eza "${base_args[@]}" "${level_flag[@]}" "$@"
  return $?
}

# List all files including dotfiles
ll() {
  __eza_with_optional_depth -alh --icons --group-directories-first --time-style=iso -- "$@"
  return $?
}

# List files excluding dotfiles
lx() {
  __eza_with_optional_depth -lh --icons --group-directories-first --time-style=iso -- "$@"
  return $?
}

# Tree view with all files
lt() {
  __eza_with_optional_depth -aT --group-directories-first --icons -- "$@"
  return $?
}

# Long-format tree view with all files
llt() {
  # Inherit ll logic and add tree flag (-T)
  ll "$@" -T
  return $?
}

# Tree views with depth limits
alias lt2='lt -L 2'
alias lt3='lt -L 3'
alias lt5='lt -L 5'

alias llt2='llt -L 2'
alias llt3='llt -L 3'
alias llt5='llt -L 5'

# Tree view excluding dotfiles
alias lxt='lx -T'

# Tree views excluding dotfiles with depth limits
alias lxt2='lxt -L 2'
alias lxt3='lxt -L 3'
alias lxt5='lxt -L 5'
