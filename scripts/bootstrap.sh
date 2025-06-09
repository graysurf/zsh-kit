[[ -n "$__BOOTSTRAP_LOADED" ]] && return
__BOOTSTRAP_LOADED=1

# Load a script and measure how long it takes
load_with_timing() {
  typeset file="$1"
  typeset label="${2:-$(basename "$file")}"
  [[ ! -f "$file" ]] && return

  typeset start_time=$(gdate +%s%3N 2>/dev/null || date +%s%3N)
  [[ -n "$ZSH_DEBUG" ]] && echo "🔍 Loading: $file"
  source "$file"
  typeset end_time=$(gdate +%s%3N 2>/dev/null || date +%s%3N)
  typeset duration=$((end_time - start_time))

  printf "✅ Loaded %s in %dms\n" "$label" "$duration"
}

# Recursively collect all .sh files under given directories
collect_scripts() {
  for dir in "$@"; do
    print -l "$dir"/**/*.sh(N)
  done
}

# Load a group of scripts with timing, supporting exclusions
load_script_group() {
  typeset group_name="$1"
  typeset base_dir="$2"
  shift 2
  typeset -a exclude=("$@")  # 接收展開後的 array

  [[ -n "$ZSH_DEBUG" ]] && {
    echo "🗂 Loading group: $group_name"
    echo "🔽 Base: $base_dir"
    echo "🚫 Exclude:"
    printf '   - %s\n' "${exclude[@]}"
  }

  typeset -a paths
  paths=(${(f)"$(
    collect_scripts "$base_dir" | grep -vFxf <(printf "%s\n" "${exclude[@]}")
  )"})

  for file in "${paths[@]}"; do
    load_with_timing "$file"
  done
}
