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
# Load user-defined scripts with timing (except duplicates)
# ──────────────────────────────
excluded_files=(
  "$ZDOTDIR/scripts/env.sh"
  "$ZDOTDIR/scripts/plugins.sh"
  "$ZDOTDIR/scripts/completion.zsh"
)

for file in "$ZDOTDIR/scripts/"**/*.sh "$ZDOTDIR/.private/"**/*.sh; do
  for excluded in "${excluded_files[@]}"; do
    [[ "$file" == "$excluded" ]] && continue 2
  done
  load_with_timing "$file"
done

# ──────────────────────────────
# Source environment and plugins
# ──────────────────────────────

# Load `env.sh` last among early scripts because it sets critical global variables
# (e.g., PATH, ZDOTDIR). Loading it too early may interfere with plugin or script logic.
load_with_timing "$ZDOTDIR/scripts/env.sh"

# `plugins.sh` initializes plugin managers like Antidote.
# It must run after env is fully set up, or some plugins might misbehave
# (especially if fpath or environment paths aren't ready).
load_with_timing "$ZDOTDIR/scripts/plugins.sh"

# `completion.zsh` sets up compinit, zstyle, and global completion configs.
# It must run after plugins are loaded, or some completion definitions will be missing.
# Running compinit too early can skip over completions provided by plugins.
load_with_timing "$ZDOTDIR/scripts/completion.zsh"

