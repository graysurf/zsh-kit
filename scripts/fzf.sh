#!/bin/bash

# ────────────────────────────────────────────────────────
# PATH & fzf initialization (for Homebrew on macOS ARM)
# ────────────────────────────────────────────────────────

if [[ ! "$PATH" == */opt/homebrew/opt/fzf/bin* ]]; then
  PATH="${PATH:+${PATH}:}/opt/homebrew/opt/fzf/bin"
fi

# Auto-completion
[[ $- == *i* ]] && source "/opt/homebrew/opt/fzf/shell/completion.zsh" 2>/dev/null

# Key bindings
source "/opt/homebrew/opt/fzf/shell/key-bindings.zsh"

# ────────────────────────────────────────────────────────
# Environment config
# ────────────────────────────────────────────────────────

export FZF_CTRL_T_COMMAND='fd --type f -t d --hidden --follow --exclude .git -E .cache'
export FZF_CTRL_T_OPTS="--preview 'bat --color \"always\" {}'"
export FZF_ALT_C_COMMAND="fd --type d --hidden --follow"

# ────────────────────────────────────────────────────────
# Unalias to avoid redefinition
# ────────────────────────────────────────────────────────

unalias fc fe fgs fzf-process fzf-env 2>/dev/null

# ────────────────────────────────────────────────────────
# fzf utilities
# ────────────────────────────────────────────────────────

# Interactive history search (ZSH/Bash compatible)
fzf-history() {
  eval $(
    ([ -n "$ZSH_NAME" ] && fc -l 1 || history) |
      fzf +s --tac |
      sed -E 's/ *[0-9]*\*? *//' |
      sed -E 's/\\/\\\\/g'
  )
}

# Open file preview and cd into its directory
fzf-preview() {
  local file
  local dir
  file=$(fzf --preview 'bat --color "always" {}' +m -q "$1") &&
    dir=$(dirname "$file") &&
    cd "$dir"
}

# Kill process by fzf-picked PID
fzf-kill() {
  local pid
  pid=$(ps -ef | sed 1d | fzf -m | awk '{print $2}')

  if [ "x$pid" != "x" ]; then
    echo $pid | xargs kill -${1:-9}
  fi
}

alias fzf-process='ps aux | fzf'
alias fzf-env='env | fzf'

# ────────────────────────────────────────────────────────
# fzf + eza integrations
# ────────────────────────────────────────────────────────

# Directory jump with tree preview via eza
fzf-cd() {
  local dir
  dir=$(eza --only-dirs --color=always |
    fzf --ansi \
        --preview "eza -alh --icons --group-directories-first --color=always {}") &&
    cd "$dir"
}
alias fc='fzf-cd'

# Search file, preview containing folder with eza
fzf-eza-preview() {
  local file
  file=$(fd --type f --hidden --exclude .git |
    fzf --preview 'eza -al --color=always $(dirname {})') &&
    cd "$(dirname "$file")"
}
alias fe='fzf-eza-preview'

# Git status picker with eza and diff preview
fzf-git-status() {
  git status -s | fzf --no-sort --reverse \
    --preview 'eza -alh --icons --group-directories-first $(dirname {2}) && git diff --color=always {2}' \
    --bind=ctrl-j:preview-down \
    --bind=ctrl-k:preview-up \
    --preview-window=right:60%:wrap
}
alias fgs='fzf-git-status'
