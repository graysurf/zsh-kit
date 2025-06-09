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
  [[ -n "$ZSH_DEBUG" ]] && echo "🔍 Loading: $file"
  source "$file"
  local end_time=$(gdate +%s%3N 2>/dev/null || date +%s%3N)
  local duration=$((end_time - start_time))

  printf "✅ Loaded %s in %dms\n" "$label" "$duration"
}

# ──────────────────────────────
# Zsh script directory structure
# ──────────────────────────────
export ZSH_SCRIPT_DIR="$ZDOTDIR/scripts"
export ZSH_PRIVATE_SCRIPT_DIR="$ZDOTDIR/.private"

collect_scripts() {
  for dir in "$@"; do
    print -l "$dir"/**/*.sh(N)
  done
}

# ──────────────────────────────
# Load script group with exclusion and debug
# ──────────────────────────────
load_script_group() {
  local group_name="$1"
  local base_dir="$2"
  local -a exclude=("${(@f)$(< "$3")}")
  local -a paths

  [[ -n "$ZSH_DEBUG" ]] && {
    echo "🗂 Loading group: $group_name"
    echo "🔽 Base: $base_dir"
    echo "🚫 Exclude:"
    printf '   - %s\n' "${exclude[@]}"
  }

  paths=(${(f)"$(
    collect_scripts "$base_dir" |
    grep -vFxf <(printf "%s\n" "${exclude[@]}")
  )"})

  for file in "${paths[@]}"; do
    load_with_timing "$file"
  done
}

# ──────────────────────────────
# Load public scripts (excluding special core scripts)
# ──────────────────────────────
ZSH_SCRIPT_EXCLUDE_LIST=$(mktemp)
cat > "$ZSH_SCRIPT_EXCLUDE_LIST" <<EOF
$ZSH_SCRIPT_DIR/env.sh
$ZSH_SCRIPT_DIR/plugins.sh
$ZSH_SCRIPT_DIR/completion.zsh
$ZSH_PRIVATE_SCRIPT_DIR/development.sh
EOF

load_script_group "Public Scripts" "$ZSH_SCRIPT_DIR" "$ZSH_SCRIPT_EXCLUDE_LIST"

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

# ──────────────────────────────
# Load private scripts
# ──────────────────────────────
ZSH_PRIVATE_SCRIPT_EXCLUDE_LIST=$(mktemp)
cat > "$ZSH_PRIVATE_SCRIPT_EXCLUDE_LIST" <<EOF
$ZSH_PRIVATE_SCRIPT_DIR/development.sh
EOF

load_script_group "Private Scripts" "$ZSH_PRIVATE_SCRIPT_DIR" "$ZSH_PRIVATE_SCRIPT_EXCLUDE_LIST"

# ──────────────────────────────
# Load development.sh last with timing
# ──────────────────────────────
dev_script="$ZSH_PRIVATE_SCRIPT_DIR/development.sh"
[[ -f "$dev_script" ]] && load_with_timing "$dev_script" "$(basename "$dev_script") (delayed)"

# Cleanup temporary exclude files
rm -f "$ZSH_SCRIPT_EXCLUDE_LIST" "$ZSH_PRIVATE_SCRIPT_EXCLUDE_LIST"
