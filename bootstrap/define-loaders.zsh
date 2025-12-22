# Only define once
typeset -f load_script >/dev/null && return

# Load a script and measure how long it takes
load_with_timing() {
  typeset file="${1-}" label="${2-}"
  [[ -n "$file" ]] || return 0
  [[ -n "$label" ]] || label="${file:t}"
  [[ -f "$file" ]] || return 0

  typeset -i use_epochrealtime=0
  if (( ${+EPOCHREALTIME} )); then
    use_epochrealtime=1
  else
    zmodload zsh/datetime 2>/dev/null && use_epochrealtime=1
  fi

  typeset -F start_time=0 end_time=0
  if (( use_epochrealtime )); then
    start_time="$EPOCHREALTIME"
  else
    start_time="$SECONDS"
  fi

  if [[ "${ZSH_DEBUG:-0}" -ge 1 ]]; then
    printf "🔍 Loading: %s\n" "$file"
  fi

  source "$file"
  typeset -i source_status=$?

  if (( use_epochrealtime )); then
    end_time="$EPOCHREALTIME"
  else
    end_time="$SECONDS"
  fi

  typeset -i duration_ms=0
  duration_ms=$(( (end_time - start_time) * 1000 ))
  (( duration_ms < 0 )) && duration_ms=0

  # ✅ Always show timing
  printf "✅ Loaded %s in %dms\n" "$label" "$duration_ms"
  return "$source_status"
}

# Recursively collect all .sh and .zsh files under given directories
collect_scripts() {
  for dir in "$@"; do
    print -l "$dir"/**/*.sh(N) "$dir"/**/*.zsh(N)
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
