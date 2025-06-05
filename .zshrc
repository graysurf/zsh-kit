# ──────────────────────────────
# Define Zsh environment paths early (must be first!)
# ──────────────────────────────
export ZDOTDIR="$HOME/.config/zsh"
export ZSH_CACHE_DIR="${ZSH_CACHE_DIR:-$ZDOTDIR/cache}"
export ZSH_COMPDUMP="$ZSH_CACHE_DIR/zcompdump"
export _Z_DATA="$ZSH_CACHE_DIR/.z"
export ZSHZ_DATA="$_Z_DATA"
export HISTFILE="$ZSH_CACHE_DIR/.zsh_history"

# Ensure cache dir exists
[[ -d "$ZSH_CACHE_DIR" ]] || mkdir -p "$ZSH_CACHE_DIR"

# ──────────────────────────────
# Source environment and plugins
# ──────────────────────────────
source "$ZDOTDIR/scripts/env.sh"
source "$ZDOTDIR/scripts/plugins.sh"

# ──────────────────────────────
# iTerm2 shell integration
# ──────────────────────────────
if [[ -f "$ZDOTDIR/scripts/.iterm2_shell_integration.zsh" ]]; then
  source "$ZDOTDIR/scripts/.iterm2_shell_integration.zsh"
fi

# ──────────────────────────────
# Utility functions
# ──────────────────────────────

# Reload .zshrc
reload() {
  source "$ZDOTDIR/.zshrc" && echo "🔁 Reloaded .zshrc"
}

# Open Zsh config in VSCode
edit-zsh() {
  local cwd="$(pwd)"
  code "$ZDOTDIR"
  cd "$cwd" >/dev/null
}

# Use Yazi to navigate, then cd to result
y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(< "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    builtin cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}

# ──────────────────────────────
# Load user-defined scripts with timing (except eza.sh)
# ──────────────────────────────
for file in "$ZDOTDIR/scripts/"*.sh "$ZDOTDIR/.private/"*.sh; do
  [[ "$file" == *"/eza.sh" ]] && continue
  [[ ! -f "$file" ]] && continue  # Skip if file doesn't exist

  start_time=$(gdate +%s%3N 2>/dev/null || date +%s%3N)
  source "$file"
  end_time=$(gdate +%s%3N 2>/dev/null || date +%s%3N)
  duration=$((end_time - start_time))

  printf "✅ Loaded %s in %dms\n" "$(basename "$file")" "$duration"
done


# ──────────────────────────────
# Load eza.sh last with timing
# ──────────────────────────────
eza_script="$ZDOTDIR/scripts/eza.sh"
if [[ -f "$eza_script" ]]; then
  start_time=$(gdate +%s%3N 2>/dev/null || date +%s%3N)
  source "$eza_script"
  end_time=$(gdate +%s%3N 2>/dev/null || date +%s%3N)
  duration=$((end_time - start_time))
  printf "✅ Loaded %s in %dms (delayed)\n" "$(basename "$eza_script")" "$duration"
fi