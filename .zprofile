# Use unique path entries (prevents duplicates)
typeset -U path PATH

# Prepend critical paths to PATH
path=(
  /opt/homebrew/bin
  /usr/local/go/bin
  /usr/local/bin
  /usr/bin
  $HOME/bin
  $ZDOTDIR/tools/git
  $path
)

# Homebrew environment setup (login shell only)
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Load optional login shell config
[[ -f "$ZDOTDIR/scripts/login.sh" ]] && source "$ZDOTDIR/scripts/login.sh"

# export ZSH_DEBUG=1
