# ──────────────────────────────
# Shell integration + session
# ──────────────────────────────
export SHELL_SESSIONS_DISABLE=1
export GPG_TTY="$(tty)"

# ──────────────────────────────
# 1Password SSH agent
# ──────────────────────────────
export SSH_AUTH_SOCK="$HOME/Library/Group Containers/3BUA8C4S2C.com.1password/t/agent.sock"

# ──────────────────────────────
# Rust environment (cargo)
# ──────────────────────────────
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"

