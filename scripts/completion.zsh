# ──────────────────────────────
# Completion system (eager load)
# ──────────────────────────────
zstyle ':completion:*' format '%F{yellow}-- %d --%f'
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' yes
zstyle ':completion:*:options' description 'yes'
zstyle ':completion:*:options' auto-description '%d'

unsetopt nomatch
zmodload zsh/complist

zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$ZSH_COMPDUMP"

