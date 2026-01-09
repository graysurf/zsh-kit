# ───────────────────────────────────────────────────────
# Aliases and Unalias
# ────────────────────────────────────────────────────────
if command -v safe_unalias >/dev/null; then
  safe_unalias \
    ll lx lg lgx lgr \
    lt llt lgt lgxt \
    lt2 lt3 lt5 llt2 llt3 llt5 lgt2 lgt3 lgt5 \
    lxt lxt2 lxt3 lxt5 lgxt2 lgxt3 lgxt5
fi

export EZA_CONFIG_DIR="$HOME/.config/eza"

# __eza_with_optional_depth <eza-args...> -- [depth] [args...]
# Internal helper: run `eza` with an optional numeric depth (`-L`).
# Usage: __eza_with_optional_depth <eza-args...> -- [depth] [args...]
# Notes:
# - If the first arg after `--` is a number, it becomes `-L <n>`.
__eza_with_optional_depth() {
  local -a base_args level_flag
  local arg first_arg

  base_args=()
  while (( $# > 0 )); do
    arg="${1-}"
    if [[ "$arg" == -- ]]; then
      shift
      break
    fi
    base_args+=("$arg")
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

# ll
# List files (including dotfiles) using `eza`.
# Usage: ll [path...]
ll() {
  __eza_with_optional_depth -alh --icons --group-directories-first --time-style=iso -- "$@"
  return $?
}

# lx
# List files (excluding dotfiles) using `eza`.
# Usage: lx [path...]
lx() {
  __eza_with_optional_depth -lh --icons --group-directories-first --time-style=iso -- "$@"
  return $?
}

# lg
# List files (including dotfiles) with Git status using `eza`.
# Usage: lg [path...]
lg() {
  __eza_with_optional_depth -alh --icons --group-directories-first --color=always --git --time-style=iso -- "$@"
  return $?
}

# lgx
# List files (excluding dotfiles) with Git status using `eza`.
# Usage: lgx [path...]
lgx() {
  __eza_with_optional_depth -lh --icons --group-directories-first --color=always --git --time-style=iso -- "$@"
  return $?
}

# lgr
# List directories with Git repo status indicators using `eza`.
# Usage: lgr [path...]
lgr() {
  __eza_with_optional_depth -alh --icons --group-directories-first --color=always --git --git-repos --time-style=iso -- "$@"
  return $?
}

# lt
# Tree view (including dotfiles) using `eza`.
# Usage: lt [path...]
lt() {
  __eza_with_optional_depth -aT --group-directories-first --icons -- "$@"
  return $?
}

# llt
# Long-format tree view (including dotfiles) using `eza`.
# Usage: llt [path...]
llt() {
  # Inherit ll logic and add tree flag (-T)
  ll "$@" -T
  return $?
}

# lgt
# Long-format tree view (including dotfiles) with Git status via `eza`, respecting `.gitignore`.
# Usage: lgt [path...]
lgt() {
  __eza_with_optional_depth -alh -T --icons --group-directories-first --color=always --git --git-ignore --time-style=iso -- "$@"
  return $?
}

# lgxt
# Long-format tree view (excluding dotfiles) with Git status via `eza`, respecting `.gitignore`.
# Usage: lgxt [path...]
lgxt() {
  __eza_with_optional_depth -lh -T --icons --group-directories-first --color=always --git --git-ignore --time-style=iso -- "$@"
  return $?
}

# Tree views with depth limits

# lt2
# Tree view (including dotfiles) with depth 2.
# Usage: lt2 [path...]
alias lt2='lt -L 2'

# lt3
# Tree view (including dotfiles) with depth 3.
# Usage: lt3 [path...]
alias lt3='lt -L 3'

# lt5
# Tree view (including dotfiles) with depth 5.
# Usage: lt5 [path...]
alias lt5='lt -L 5'

# llt2
# Long-format tree view (including dotfiles) with depth 2.
# Usage: llt2 [path...]
alias llt2='llt -L 2'

# llt3
# Long-format tree view (including dotfiles) with depth 3.
# Usage: llt3 [path...]
alias llt3='llt -L 3'

# llt5
# Long-format tree view (including dotfiles) with depth 5.
# Usage: llt5 [path...]
alias llt5='llt -L 5'

# Git-aware tree views with depth limits

# lgt2
# Git-aware long-format tree view (including dotfiles) with depth 2.
# Usage: lgt2 [path...]
alias lgt2='lgt -L 2'

# lgt3
# Git-aware long-format tree view (including dotfiles) with depth 3.
# Usage: lgt3 [path...]
alias lgt3='lgt -L 3'

# lgt5
# Git-aware long-format tree view (including dotfiles) with depth 5.
# Usage: lgt5 [path...]
alias lgt5='lgt -L 5'

# Tree view excluding dotfiles

# lxt
# Tree view (excluding dotfiles).
# Usage: lxt [path...]
alias lxt='lx -T'

# Tree views excluding dotfiles with depth limits

# lxt2
# Tree view (excluding dotfiles) with depth 2.
# Usage: lxt2 [path...]
alias lxt2='lxt -L 2'

# lxt3
# Tree view (excluding dotfiles) with depth 3.
# Usage: lxt3 [path...]
alias lxt3='lxt -L 3'

# lxt5
# Tree view (excluding dotfiles) with depth 5.
# Usage: lxt5 [path...]
alias lxt5='lxt -L 5'

# Git-aware tree views excluding dotfiles with depth limits

# lgxt2
# Git-aware tree view (excluding dotfiles) with depth 2.
# Usage: lgxt2 [path...]
alias lgxt2='lgxt -L 2'

# lgxt3
# Git-aware tree view (excluding dotfiles) with depth 3.
# Usage: lgxt3 [path...]
alias lgxt3='lgxt -L 3'

# lgxt5
# Git-aware tree view (excluding dotfiles) with depth 5.
# Usage: lgxt5 [path...]
alias lgxt5='lgxt -L 5'
