# macOS-only module.
if [[ "${OSTYPE-}" != darwin* ]]; then
  return 0 2>/dev/null || exit 0
fi

# ───────────────────────────────────────────────────────
# Aliases and Unalias
# ────────────────────────────────────────────────────────
if command -v safe_unalias >/dev/null; then
  safe_unalias \
    f hidpi \
    flushdns \
    finder-show-hidden finder-hide-hidden finder-toggle-hidden \
    ql reveal \
    caff \
    brew-update brew-cleanup \
    mactop
fi

# ────────────────────────────────────────────────────────
# PATH setup for macOS tools (Homebrew + VSCode CLI)
# ────────────────────────────────────────────────────────

if [[ -d /opt/homebrew/opt/grep/libexec/gnubin ]]; then
  case ":$PATH:" in
    *":/opt/homebrew/opt/grep/libexec/gnubin:"*) ;;
    *) export PATH="/opt/homebrew/opt/grep/libexec/gnubin:$PATH" ;;
  esac
elif [[ -d /usr/local/opt/grep/libexec/gnubin ]]; then
  case ":$PATH:" in
    *":/usr/local/opt/grep/libexec/gnubin:"*) ;;
    *) export PATH="/usr/local/opt/grep/libexec/gnubin:$PATH" ;;
  esac
fi

typeset vscode_bin='/Applications/Visual Studio Code.app/Contents/Resources/app/bin'
if [[ -d "$vscode_bin" ]]; then
  case ":$PATH:" in
    *":$vscode_bin:"*) ;;
    *) export PATH="$vscode_bin:$PATH" ;;
  esac
fi
unset vscode_bin

# ──────────────────────────────
# 1Password SSH agent
# ──────────────────────────────
typeset onepassword_sock="$HOME/Library/Group Containers/3BUA8C4S2C.com.1password/t/agent.sock"
if [[ -S "$onepassword_sock" ]]; then
  export SSH_AUTH_SOCK="$onepassword_sock"
fi
unset onepassword_sock

# ──────────────────────────────
# Shell integration + session
# ──────────────────────────────
: "${SHELL_SESSIONS_DISABLE:=1}"
export SHELL_SESSIONS_DISABLE

# ────────────────────────────────────────────────────────
# macOS-specific convenience aliases
# ────────────────────────────────────────────────────────

# f: Open a file or directory with the default macOS app.
# Usage: f <path...>
f() {
  emulate -L zsh
  setopt err_return

  typeset opener=''
  if [[ -x /usr/bin/open ]]; then
    opener='/usr/bin/open'
  elif command -v open >/dev/null 2>&1; then
    opener="$(command -v open)"
  else
    print -u2 -r -- "❌ open not found"
    return 127
  fi

  "$opener" "$@"
}

# hidpi
# Run the one-key-hidpi installer script (downloads and executes remote code).
# Usage: hidpi
# Safety:
# - Executes a remote script via curl; review the URL before running.
alias hidpi='bash -c "$(curl -fsSL https://raw.githubusercontent.com/xzhih/one-key-hidpi/master/hidpi.sh)"'

# flushdns
# Flush macOS DNS caches (mDNSResponder + dscacheutil).
# Usage: flushdns
# Notes:
# - Requires sudo.
flushdns() {
  emulate -L zsh
  setopt pipe_fail err_return

  if ! command -v dscacheutil >/dev/null 2>&1; then
    print -u2 -r -- "❌ dscacheutil not found"
    return 127
  fi
  if ! command -v killall >/dev/null 2>&1; then
    print -u2 -r -- "❌ killall not found"
    return 127
  fi

  sudo dscacheutil -flushcache
  sudo killall -HUP mDNSResponder 2>/dev/null || true
  sudo killall -HUP mDNSResponderHelper 2>/dev/null || true
}

# ────────────────────────────────────────────────────────
# Finder helpers
# ────────────────────────────────────────────────────────

# _macos_restart_finder
# Restart Finder to apply preference changes.
# Usage: _macos_restart_finder
_macos_restart_finder() {
  emulate -L zsh
  setopt err_return

  command killall Finder >/dev/null 2>&1 || true
}

# finder-show-hidden
# Show hidden files in Finder.
# Usage: finder-show-hidden
finder-show-hidden() {
  emulate -L zsh
  setopt err_return

  command defaults write com.apple.finder AppleShowAllFiles -bool true
  _macos_restart_finder
}

# finder-hide-hidden
# Hide hidden files in Finder.
# Usage: finder-hide-hidden
finder-hide-hidden() {
  emulate -L zsh
  setopt err_return

  command defaults write com.apple.finder AppleShowAllFiles -bool false
  _macos_restart_finder
}

# finder-toggle-hidden
# Toggle hidden file visibility in Finder.
# Usage: finder-toggle-hidden
finder-toggle-hidden() {
  emulate -L zsh
  setopt err_return

  typeset current=''
  current="$(command defaults read com.apple.finder AppleShowAllFiles 2>/dev/null || true)"
  case "$current" in
    1|true|TRUE|yes|YES) finder-hide-hidden ;;
    *) finder-show-hidden ;;
  esac
}

# reveal <path...>
# Reveal one or more paths in Finder.
# Usage: reveal <path...>
reveal() {
  emulate -L zsh
  setopt err_return

  if (( $# == 0 )); then
    print -u2 -r -- "Usage: reveal <path...>"
    return 2
  fi

  typeset opener=''
  if [[ -x /usr/bin/open ]]; then
    opener='/usr/bin/open'
  elif command -v open >/dev/null 2>&1; then
    opener="$(command -v open)"
  else
    print -u2 -r -- "❌ open not found"
    return 127
  fi

  typeset path=''
  for path in "$@"; do
    "$opener" -R -- "$path"
  done
}

# ql <path...>
# Quick Look preview for one or more files.
# Usage: ql <path...>
ql() {
  emulate -L zsh
  setopt err_return

  if (( $# == 0 )); then
    print -u2 -r -- "Usage: ql <path...>"
    return 2
  fi
  if ! command -v qlmanage >/dev/null 2>&1; then
    print -u2 -r -- "❌ qlmanage not found"
    return 127
  fi

  # Detach (qlmanage blocks until the panel is closed).
  qlmanage -p "$@" >/dev/null 2>&1 &!
}

# ────────────────────────────────────────────────────────
# Power helpers
# ────────────────────────────────────────────────────────

# caff [minutes] [command...]
# Keep the system awake via `caffeinate`.
# Usage: caff [minutes] [command...]
# Notes:
# - If the first arg is a number, it is interpreted as minutes (uses `-t`).
caff() {
  emulate -L zsh
  setopt err_return

  if ! command -v caffeinate >/dev/null 2>&1; then
    print -u2 -r -- "❌ caffeinate not found"
    return 127
  fi

  if (( $# == 0 )); then
    caffeinate -dimsu
    return $?
  fi

  if [[ "$1" == <-> ]]; then
    typeset -i minutes=$1
    shift
    caffeinate -dimsu -t $(( minutes * 60 )) "$@"
    return $?
  fi

  caffeinate -dimsu "$@"
}

# ────────────────────────────────────────────────────────
# Homebrew helpers
# ────────────────────────────────────────────────────────

# brew-update
# Update Homebrew and upgrade packages.
# Usage: brew-update
brew-update() {
  emulate -L zsh
  setopt err_return

  if ! command -v brew >/dev/null 2>&1; then
    print -u2 -r -- "❌ brew not found"
    return 127
  fi

  brew update
  brew upgrade
}

# brew-cleanup
# Cleanup Homebrew caches and remove unused deps.
# Usage: brew-cleanup
brew-cleanup() {
  emulate -L zsh
  setopt err_return

  if ! command -v brew >/dev/null 2>&1; then
    print -u2 -r -- "❌ brew not found"
    return 127
  fi

  brew autoremove 2>/dev/null || true
  brew cleanup
}

# mactop
# Run mactop with sudo and a fixed color theme.
# Usage: mactop
mactop() {
  emulate -L zsh
  setopt err_return

  typeset mactop_bin=''
  if [[ -x /opt/homebrew/bin/mactop ]]; then
    mactop_bin='/opt/homebrew/bin/mactop'
  elif [[ -x /usr/local/bin/mactop ]]; then
    mactop_bin='/usr/local/bin/mactop'
  elif command -v mactop >/dev/null 2>&1; then
    mactop_bin="$(command -v mactop)"
  else
    print -u2 -r -- "❌ mactop not found"
    return 127
  fi

  sudo "$mactop_bin" --color cyan
}
