# Centralized environment variable config for tools (fzf, bat, git, etc.)

# ──────────────────────────────
# Shell integration + session
# ──────────────────────────────
export GPG_TTY="$(tty)"

# ────────────────────────────────────────────────────────
# FZF Environment config
# ────────────────────────────────────────────────────────
# Set preview window layout if not already defined
: "${FZF_PREVIEW_WINDOW:=right:60%:wrap}"
export FZF_PREVIEW_WINDOW

# Set max depth for fd-based searches
: "${FZF_FILE_MAX_DEPTH:=5}"
export FZF_FILE_MAX_DEPTH

# Set default delimiters for custom preview blocks
: "${FZF_DEF_DELIM:="[FZF-DEF]"}"
export FZF_DEF_DELIM

: "${FZF_DEF_DELIM_END:="[FZF-DEF-END]"}"
export FZF_DEF_DELIM_END

# Ensure FZF_DEFAULT_OPTS is initialized
: "${FZF_DEFAULT_OPTS:=}"
export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS \
  --bind=ctrl-j:preview-down \
  --bind=ctrl-k:preview-up \
  --bind=ctrl-b:preview-page-up \
  --bind=ctrl-f:preview-page-down \
  --bind=ctrl-h:preview-top \
  --bind=ctrl-l:preview-bottom"

# FZF key bindings (e.g., Ctrl-R, Ctrl-T, Alt-C)
source "/opt/homebrew/opt/fzf/shell/key-bindings.zsh"

export FZF_CTRL_T_COMMAND='fd --type f -t d --hidden --follow --exclude .git -E .cache'
export FZF_CTRL_T_OPTS="--preview 'bat --color \"always\" {}'"
export FZF_ALT_C_COMMAND="fd --type d --hidden --follow"





