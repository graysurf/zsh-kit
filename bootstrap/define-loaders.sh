# Only define once
typeset -f load_script >/dev/null && return

# Load a script and measure how long it takes
load_with_timing() {
  typeset file="$1"
  typeset label="${2:-$(basename "$file")}"
  [[ ! -f "$file" ]] && return

  typeset start_time=$(gdate +%s%3N 2>/dev/null || date +%s%3N)

  if [[ "${ZSH_DEBUG:-0}" -ge 1 ]]; then
    printf "🔍 Loading: %s\n" "$file"
  fi

  source "$file"

  typeset end_time=$(gdate +%s%3N 2>/dev/null || date +%s%3N)
  typeset duration=$((end_time - start_time))

  # ✅ Always show timing
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
    printf "⚠️  File not found: %s\n" "$file" >&2
  fi
}

# Load a group of scripts with timing, supporting exclusions and detailed debug
load_script_group() {
  typeset group_name="$1"
  typeset base_dir="$2"
  shift 2
  typeset -a exclude=("$@")

  typeset -a all_scripts filtered_scripts
  all_scripts=(${(f)"$(collect_scripts "$base_dir")"})

  if [[ "${ZSH_DEBUG:-0}" -ge 1 ]]; then
    printf "🗂 Loading group: %s\n" "$group_name"
    printf "🔽 Base: %s\n" "$base_dir"
    printf "🚫 Exclude:\n"
    for ex in "${exclude[@]}"; do
      printf "   - %s\n" "$ex"
    done
  fi

  if [[ "${ZSH_DEBUG:-0}" -ge 2 ]]; then
    printf "📦 All collected scripts:\n"
    printf '   • %s\n' "${all_scripts[@]}"
  fi

  filtered_scripts=(${(f)"$(
    printf "%s\n" "${all_scripts[@]}" | grep -vFxf <(printf "%s\n" "${exclude[@]}")
  )"})

  if [[ "${ZSH_DEBUG:-0}" -ge 2 ]]; then
    printf "✅ Scripts after filtering:\n"
    printf '   → %s\n' "${filtered_scripts[@]}"
  fi

  for file in "${filtered_scripts[@]}"; do
    load_with_timing "$file"
  done
}
