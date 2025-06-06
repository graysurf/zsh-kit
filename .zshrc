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
# Load file with timing helper
# ──────────────────────────────
load_with_timing() {
  local file="$1"
  local label="${2:-$(basename "$file")}"
  [[ ! -f "$file" ]] && return

  local start_time=$(gdate +%s%3N 2>/dev/null || date +%s%3N)
  source "$file"
  local end_time=$(gdate +%s%3N 2>/dev/null || date +%s%3N)
  local duration=$((end_time - start_time))

  printf "✅ Loaded %s in %dms\n" "$label" "$duration"
}

# ──────────────────────────────
# Source environment and plugins
# ──────────────────────────────
load_with_timing "$ZDOTDIR/scripts/env.sh"
load_with_timing "$ZDOTDIR/scripts/plugins.sh"

# ──────────────────────────────
# iTerm2 shell integration
# ──────────────────────────────
load_with_timing "$ZDOTDIR/scripts/iterm2_shell_integration.zsh"

# ──────────────────────────────
# Load user-defined scripts with timing (except duplicates)
# ──────────────────────────────
for file in "$ZDOTDIR/scripts/"*.sh "$ZDOTDIR/.private/"*.sh; do
  case "$file" in
    *"/env.sh" | *"/plugins.sh" | *"/eza.sh" | *"/.iterm2_shell_integration.zsh")
      continue
      ;;
  esac

  load_with_timing "$file"
done

# ──────────────────────────────
# Load eza.sh last with timing
# ──────────────────────────────
eza_script="$ZDOTDIR/scripts/eza.sh"
[[ -f "$eza_script" ]] && load_with_timing "$eza_script" "$(basename "$eza_script") (delayed)"
