# Use unique path entries (prevents duplicates)
typeset -U path PATH

# Prepend critical paths to PATH
path=(
  /usr/local/bin
  /usr/bin
  $HOME/bin
  $HOME/.local/bin
  $path
)

# Cached CLI wrappers (for subshells like fzf preview)
typeset wrappers_zsh="${ZSH_SCRIPT_DIR:-$ZDOTDIR/scripts}/_internal/wrappers.zsh"
typeset wrappers_bin="${ZSH_CACHE_DIR:-$ZDOTDIR/cache}/wrappers/bin"
typeset wrappers_check_cmd='git-scope'
typeset wrappers_check_path="$wrappers_bin/$wrappers_check_cmd"
if [[ -f "$wrappers_zsh" && ! -x "$wrappers_check_path" ]]; then
  source "$wrappers_zsh"
  [[ -o interactive ]] && _wrappers::ensure_all || _wrappers::ensure_all >/dev/null 2>&1 || true
fi
if [[ -x "$wrappers_check_path" ]]; then
  path=("$wrappers_bin" $path)
fi

# Homebrew environment setup (login shell only)
typeset homebrew_path=''
if command -v brew >/dev/null 2>&1; then
  homebrew_path="$(command -v brew)"
else
  typeset home="${HOME-}"
  typeset -a candidates=(
    /opt/homebrew/bin/brew
    /usr/local/bin/brew
    /home/linuxbrew/.linuxbrew/bin/brew
  )
  [[ -n "$home" ]] && candidates+=("$home/.linuxbrew/bin/brew")

  typeset candidate=''
  for candidate in "${candidates[@]}"; do
    [[ -x "$candidate" ]] || continue
    homebrew_path="$candidate"
    break
  done
fi

if [[ -n "$homebrew_path" ]]; then
  eval "$("$homebrew_path" shellenv)"
  export HOMEBREW_AUTO_UPDATE_SECS=604800 # 7 days
fi
