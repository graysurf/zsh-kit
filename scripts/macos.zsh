# ───────────────────────────────────────────────────────
# Aliases and Unalias
# ────────────────────────────────────────────────────────
if command -v safe_unalias >/dev/null; then
  safe_unalias \
    mactop
fi

# ────────────────────────────────────────────────────────
# PATH setup for macOS tools (Homebrew + VSCode CLI)
# ────────────────────────────────────────────────────────

export PATH="/usr/local/opt/grep/libexec/gnubin:$PATH"
export PATH="/Applications/Visual Studio Code.app/Contents/Resources/app/bin:$PATH"

# ──────────────────────────────
# 1Password SSH agent
# ──────────────────────────────
export SSH_AUTH_SOCK="$HOME/Library/Group Containers/3BUA8C4S2C.com.1password/t/agent.sock"

# ──────────────────────────────
# Shell integration + session
# ──────────────────────────────
export GPG_TTY="$(tty 2>/dev/null || true)"
export SHELL_SESSIONS_DISABLE=1

# ────────────────────────────────────────────────────────
# macOS-specific convenience aliases
# ────────────────────────────────────────────────────────

alias f='open'  # Quick open file or dir with default macOS app
alias weather='curl wttr.in'

alias hidpi='bash -c "$(curl -fsSL https://raw.githubusercontent.com/xzhih/one-key-hidpi/master/hidpi.sh)"'

export mactop() {
  sudo /opt/homebrew/bin/mactop --color cyan
}
