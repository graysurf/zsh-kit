# Only define once
typeset -f load_script >/dev/null && return

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

# Load a single script file with timing and optional debug log
load_script() {
  typeset file="$1"

  if [[ -f "$file" ]]; then
    load_with_timing "$file"
  else
    echo "⚠️  File not found: $file" >&2
  fi
}

# Load a group of scripts with timing, supporting exclusions and detailed debug
load_script_group() {
  typeset group_name="$1"
  typeset base_dir="$2"
  shift 2
  typeset -a exclude=("$@")  # Exclusion list

  typeset -a all_scripts filtered_scripts

  all_scripts=(${(f)"$(collect_scripts "$base_dir")"})

  if (( ${+ZSH_DEBUG} )); then
    echo "🗂 Loading group: $group_name"
    echo "🔽 Base: $base_dir"
    echo "🚫 Exclude:"
    for ex in "${exclude[@]}"; do
      echo "   - $ex"
    done
    if [[ "$ZSH_DEBUG" -ge 2 ]]; then
      echo "📦 All collected scripts:"
      printf '   • %s\n' "${all_scripts[@]}"
    fi
  fi

  filtered_scripts=(${(f)"$(
    printf "%s\n" "${all_scripts[@]}" | grep -vFxf <(printf "%s\n" "${exclude[@]}")
  )"})

  if [[ "$ZSH_DEBUG" -ge 2 ]]; then
    echo "✅ Scripts after filtering:"
    printf '   → %s\n' "${filtered_scripts[@]}"
  fi

  for file in "${filtered_scripts[@]}"; do
    load_with_timing "$file"
  done
}



