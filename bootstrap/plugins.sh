# ──────────────────────────────
# Load typeset zsh plugins manually
# ──────────────────────────────

ZSH_PLUGINS_DIR="$ZDOTDIR/plugins"

# --------------------------------------------
# Plugin Declaration Table
# --------------------------------------------
ZSH_PLUGINS=(
  "fzf-tab::fzf-tab.plugin.zsh"
  "fast-syntax-highlighting::fast-syntax-highlighting.plugin.zsh"
  "zsh-autosuggestions::zsh-autosuggestions.zsh::ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE=fg=8"
  "zsh-history-substring-search"
  "zsh-direnv"
  "zsh-abbr::zsh-abbr.plugin.zsh::abbr"
)

# --------------------------------------------
# Loader Functions
# --------------------------------------------

load_plugin_entry() {
  typeset entry="$1"
  typeset plugin_name main_file extra
  plugin_name="${entry%%::*}"
  rest="${entry#*::}"

  if [[ "$entry" == *"::"* ]]; then
    main_file="${rest%%::*}"
    extra="${rest#*::*}"
  else
    main_file="${plugin_name}.plugin.zsh"
    extra=""
  fi

  typeset plugin_path="$ZSH_PLUGINS_DIR/$plugin_name"
  typeset full_path="$plugin_path/$main_file"

  if [[ -f "$full_path" ]]; then
    if [[ "$extra" == "abbr" ]]; then
      # Special case: zsh-abbr needs fpath and job-queue
      fpath+=("$plugin_path/completions")
      fpath+=("$plugin_path/zsh-job-queue")
      source "$plugin_path/zsh-job-queue/zsh-job-queue.plugin.zsh"
    fi

    # Set any extra env var if provided
    if [[ "$extra" == *=* ]]; then
      eval "$extra"
    fi

    source "$full_path"
  fi
}

# --------------------------------------------
# Load All Declared Plugins
# --------------------------------------------
for plugin_entry in "${ZSH_PLUGINS[@]}"; do
  load_plugin_entry "$plugin_entry"
done

# ──────────────────────────────
# Zoxide smart directory jumping
# ──────────────────────────────

# Initialize zoxide (faster alternative to z/zsh-z)
eval "$(zoxide init zsh)"

# Override `z` to: jump to matched dir AND run `ll`
z() {
  if zoxide query -l "$@" &>/dev/null; then
    builtin cd "$(zoxide query "$@")" && {
      echo -e "\n📁 Now in: $PWD\n"
      eza -alh --icons --group-directories-first --time-style=iso
    }
  else
    echo "❌ No matching directory for: $*"
    return 1
  fi
}

# ──────────────────────────────
# Starship prompt
# ──────────────────────────────

if [[ -f "$ZDOTDIR/config/starship.toml" ]]; then
  export STARSHIP_CONFIG="$ZDOTDIR/config/starship.toml"
fi
eval "$(starship init zsh)"

# ──────────────────────────────
# Shell behavior options
# ──────────────────────────────

setopt nocaseglob
setopt nocasematch
setopt extended_glob

# ──────────────────────────────
# History substring search key bindings
# ──────────────────────────────

bindkey "$terminfo[kcuu1]" history-substring-search-up
bindkey "$terminfo[kcud1]" history-substring-search-down
bindkey -M vicmd 'k' history-substring-search-up
bindkey -M vicmd 'j' history-substring-search-down

