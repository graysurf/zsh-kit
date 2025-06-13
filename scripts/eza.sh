# ───────────────────────────────────────────────────────
# Aliases and Unalias
# ────────────────────────────────────────────────────────
if command -v safe_unalias >/dev/null; then
  safe_unalias \
    ll lx lt llt lt2 lt3 lt5 \
    llt2 llt3 llt5 \
    lxt lxt2 lxt3 lxt5
fi

# List all files including dotfiles
ll() {
  # If first argument is a number, treat it as depth (-L)
  local level_flag=()
  if [[ "$1" =~ '^[0-9]+$' ]]; then
    level_flag=(-L "$1")
    shift
  fi
  eza -alh --icons --group-directories-first --time-style=iso "${level_flag[@]}" "$@"
}

# List all files including dotfiles (with color=always)
lx() {
  # If first argument is a number, treat it as depth (-L)
  local level_flag=()
  if [[ "$1" =~ '^[0-9]+$' ]]; then
    level_flag=(-L "$1")
    shift
  fi
  eza -lh --icons --group-directories-first --color=always --time-style=iso "${level_flag[@]}" "$@"
}

# Tree view with all files
lt() {
  # If first argument is a number, treat it as depth (-L)
  local level_flag=()
  if [[ "$1" =~ '^[0-9]+$' ]]; then
    level_flag=(-L "$1")
    shift
  fi
  eza -aT --group-directories-first --color=always --icons "${level_flag[@]}" "$@"
}

# Long-format tree view with all files
llt() {
  # Inherit ll logic and add tree flag (-T)
  ll "$@" -T
}

# Tree views with depth limits
alias lt2='ll -T -L 2'
alias lt3='ll -T -L 3'
alias lt5='ll -T -L 5'

alias llt2='ll -T -L 2'
alias llt3='ll -T -L 3'
alias llt5='ll -T -L 5'

# Tree view excluding dotfiles
alias lxt='lx -T'

# Tree views excluding dotfiles with depth limits
alias lxt2='lx -T -L 2'
alias lxt3='lx -T -L 3'
alias lxt5='lx -T -L 5'



