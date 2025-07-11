# ──────────────────────────────
# Setup completion functions first
# ──────────────────────────────
fpath=("$ZDOTDIR/scripts/_completion" $fpath)
autoload -Uz compinit
compinit -d "$ZSH_COMPDUMP"

# ──────────────────────────────
# fzf-tab configuration (after compinit)
# ──────────────────────────────
setopt EXTENDED_GLOB GLOB_DOTS  
# Use modern menu selection
zstyle ':completion:*' menu yes select
zstyle ':completion:*:descriptions' format '[%d]'

zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# Enable fuzzy matching: case-insensitive and treat ., _, - as separators
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*'

# Enable fzf-tab with styled preview menu
zstyle ':fzf-tab:*' prefix ''
zstyle ':fzf-tab:*' fzf-command fzf
zstyle ':fzf-tab:*' fzf-flags  --height=60% --layout=reverse --prompt='⮕ '
zstyle ':fzf-tab:*' ignore-case smart

zmodload zsh/complist

zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$ZSH_COMPDUMP"

# Ensure common file‑reading commands complete both files and directories
autoload -Uz compdef
compdef _files cat less bat
