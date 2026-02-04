# ────────────────────────────────────────────────────────
# git-scope aliases (native binary integration)
# ────────────────────────────────────────────────────────
# This repo no longer ships the Zsh implementation of `git-scope`.
# The command is expected to be provided by a native binary on `PATH`.

if command -v safe_unalias >/dev/null; then
  safe_unalias gs gsc gst
fi

# gs
# Alias of `git-scope`.
# Usage: gs <command> [args...]
alias gs='git-scope'

# gsc
# Alias of `git-scope commit`.
# Usage: gsc <commit-ish> [--parent <n>] [-p|--print]
alias gsc='git-scope commit'

# gst
# Alias of `git-scope tracked`.
# Usage: gst [prefix...]
alias gst='git-scope tracked'

