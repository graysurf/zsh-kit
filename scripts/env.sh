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

# Night Owl Theme
FZF_THEME_OPTS="\
  --color=fg:#d6deeb,bg:#011627,hl:#82aaff \
  --color=fg+:#ffffff,bg+:#1d3b53,hl+:#c792ea \
  --color=info:#7fdbca,prompt:#ffcb6b,pointer:#f78c6c \
  --color=marker:#addb67,spinner:#ecc48d,header:#637777 \
  --color=border:#1d3b53"

# Key binds & Preview Controls
FZF_PREVIEW_OPTS="\
  --no-mouse \
  --preview-window=${FZF_PREVIEW_WINDOW:-right:50%:wrap} \
  --bind=ctrl-j:preview-down \
  --bind=ctrl-k:preview-up \
  --bind=ctrl-b:preview-page-up \
  --bind=ctrl-f:preview-page-down \
  --bind=ctrl-h:preview-top \
  --bind=ctrl-l:preview-bottom \
  --bind=home:first \
  --bind=end:last"

export FZF_DEFAULT_OPTS="$FZF_THEME_OPTS $FZF_PREVIEW_OPTS"

export FZF_CTRL_T_COMMAND='fd --type f -t d --hidden --follow --exclude .git -E .cache'
export FZF_CTRL_T_OPTS="--preview 'bat --color \"always\" {}'"
export FZF_ALT_C_COMMAND="fd --type d --hidden --follow"

# ────────────────────────────────────────────────────────
# BAT theme config with fallback
# ────────────────────────────────────────────────────────
if bat --list-themes 2>/dev/null | grep -q "Night-Owl"; then
  export BAT_THEME="Night-Owl"
else
  export BAT_THEME="Monokai Extended"
fi





