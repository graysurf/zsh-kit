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
  export HOMEBREW_AUTO_UPDATE_SECS=604800 # 7 days
fi
