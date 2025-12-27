# ────────────────────────────────────────────────────────
# Aliases and Unalias
# ────────────────────────────────────────────────────────
if command -v safe_unalias >/dev/null; then
  safe_unalias \
    gr grs grm grh \
    gbh gbc gdb gdbs \
    gop god goc gob \
    gcc gdc
fi

# ────────────────────────────────────────────────────────
# Git operation aliases
# ────────────────────────────────────────────────────────

# Reset staged files (equivalent to "git reset")
alias gr='git reset'

# Short aliases for common undo/reset operations
alias grs='git-reset-soft'
alias grm='git-reset-mixed'
alias grh='git-reset-hard'
alias gbh='git-back-head'
alias gbc='git-back-checkout'

# Branch cleanup aliases
alias gdb='git-delete-merged-branches'
alias gdbs='gdb --squash'

# GitHub / GitLab remote open aliases
alias gop='gh-open'
alias god='gh-open-default-branch'
alias goc='gh-open-commit'
alias gob='gh-open-branch'

# Commit context alias
alias gcc='git-commit-context'
alias gdc='git-copy-staged'
