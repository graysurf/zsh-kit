#!/bin/bash

# ────────────────────────────────────────────────────────
# Unalias to avoid redefinition
# ────────────────────────────────────────────────────────

unalias gr greset-hard guncommit gundo gpick gscope gpushf 2>/dev/null

# ────────────────────────────────────────────────────────
# Git operation aliases
# ────────────────────────────────────────────────────────

# Reset staged files (equivalent to "git reset")
alias gr='git reset'

# Full reset and clean untracked files — DANGER ZONE
alias greset-hard='git reset --hard && git clean -fd'

# Undo last commit but keep changes staged
alias guncommit='git reset --soft HEAD~1'

# Force push with lease (safer than --force)
alias gpushf='git push --force-with-lease'

# ────────────────────────────────────────────────────────
# Git workflow helper functions
# ────────────────────────────────────────────────────────

# Soft reset last commit with feedback
gundo() {
  echo "⚠️  Rewinding 1 commit (soft reset)..."
  git reset --soft HEAD~1
  echo "🌀 Your last commit is now unstaged & editable"
}

# FZF pick a commit and checkout to it
gpick() {
  git log --oneline --color=always |
    fzf --ansi --no-sort --reverse |
    cut -d ' ' -f 1 |
    xargs git checkout
}

# Preview the structure of staged files using eza
gscope() {
  git diff --name-only --cached --diff-filter=ACMRTUXB |
    xargs eza -T --icons --color=always
}
