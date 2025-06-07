# ──────────────────────────────
# Setup completion functions first
# ──────────────────────────────
fpath=("$ZDOTDIR/scripts/_completion" $fpath)
autoload -Uz compinit
compinit -d "$ZSH_COMPDUMP"

# ──────────────────────────────
# fzf-tab configuration (after compinit)
# ──────────────────────────────
# Use modern menu selection
zstyle ':completion:*' menu yes select
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' group-name ''

# Enable fzf-tab with styled preview menu
zstyle ':fzf-tab:*' fzf-command fzf
zstyle ':fzf-tab:*' fzf-flags  --height=60% --layout=reverse --prompt='⮕ '

# Colorful group headers
zstyle ':fzf-tab:*' group-colors $'\033[1;34m' $'\033[0;36m'

# Keep one group per section, avoid noisy prefix
zstyle ':fzf-tab:*' prefix ''
zstyle ':fzf-tab:*' single-group color header

# Use icons for file types (if using `eza` or `lsd`)
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# Show hidden files too
zstyle ':completion:*' file-patterns '*(-/):directories' '*:all-files'

# Optional: Use smart-case matching
zstyle ':fzf-tab:*' ignore-case smart

unsetopt nomatch
zmodload zsh/complist

zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$ZSH_COMPDUMP"
