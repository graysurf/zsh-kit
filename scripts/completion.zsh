# ──────────────────────────────
# Setup completion functions first
# ──────────────────────────────
if [[ ! -o interactive || ! -t 0 ]]; then
  return 0
fi

fpath=("$ZDOTDIR/scripts/_completion" $fpath)
autoload -Uz compinit
compinit -i -d "$ZSH_COMPDUMP"
typeset -g ZSH_COMPLETION_CACHE_DIR="${ZSH_COMPLETION_CACHE_DIR:-$ZSH_CACHE_DIR/completion-cache}"
[[ -d "$ZSH_COMPLETION_CACHE_DIR" ]] || mkdir -p -- "$ZSH_COMPLETION_CACHE_DIR"

# ──────────────────────────────
# fzf-tab configuration (after compinit)
# ──────────────────────────────
setopt EXTENDED_GLOB GLOB_DOTS  
# avoid auto-inserting common prefix before menu
unsetopt AUTO_MENU MENU_COMPLETE
# Use modern menu selection
zstyle ':completion:*' menu yes select
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' list-colors ${(s.:.)${LS_COLORS-}}
# Keep input as typed; don't auto-insert longest common prefix before showing menu
zstyle ':completion:*' insert-unambiguous false
# Enable fuzzy matching: case-insensitive; keep '-' significant so camelCase vs kebab-case don't collapse
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._]=* r:|=*'

# Enable fzf-tab with styled preview menu
zstyle ':fzf-tab:*' prefix ''
zstyle ':fzf-tab:*' fzf-command fzf
zstyle ':fzf-tab:*' fzf-flags  --height=60% --layout=reverse --prompt='⮕ '
zstyle ':fzf-tab:*' query-string input  # keep fzf query/prompt in the original typed case
zstyle ':fzf-tab:*' ignore-case smart
# do not pre-insert common prefix; open menu immediately
zstyle ':fzf-tab:*' skip-unambiguous yes

zmodload zsh/complist

zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$ZSH_COMPLETION_CACHE_DIR"

# Ensure common file‑reading commands complete both files and directories
(( ${+functions[compdef]} )) && compdef _files cat less bat
