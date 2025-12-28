# Only define once
typeset -f source_file >/dev/null && return

# Source a file and measure how long it takes
source_file() {
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

# Source a single file and always warn on missing
source_file_warn_missing() {
  typeset file="$1"

  if [[ -f "$file" ]]; then
    source_file "$file"
  else
    printf "⚠️  File not found: %s\n" "$file" >&2
  fi
}

# Recursively collect all .sh and .zsh files under given directories
collect_scripts() {
  for dir in "$@"; do
    print -l "$dir"/**/*.sh(N) "$dir"/**/*.zsh(N)
  done
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
    source_file "$file"
  done
}

# Load scripts under a directory in a deterministic order, with optional pinned
# "first" and "last" files and an exclusion list.
#
# Usage:
#   load_script_group_ordered <group-name> <base-dir> \
#     [--first <file...>] [--last <file...>] [--exclude <file...>] [--] [<exclude...>]
#
# Notes:
# - Any arguments not preceded by --first/--last/--exclude are treated as excludes
#   (for compatibility with load_script_group).
# - Pinned first/last files are always loaded in the order provided.
load_script_group_ordered() {
  typeset group_name="$1"
  typeset base_dir="$2"
  shift 2

  typeset -a first_scripts=() last_scripts=() exclude=()
  typeset mode='exclude'
  while (( $# > 0 )); do
    case "$1" in
      --first)
        mode='first'
        shift
        continue
        ;;
      --last)
        mode='last'
        shift
        continue
        ;;
      --exclude)
        mode='exclude'
        shift
        continue
        ;;
      --)
        shift
        exclude+=("$@")
        break
        ;;
      *)
        case "$mode" in
          first)  first_scripts+=("$1") ;;
          last)   last_scripts+=("$1") ;;
          *)      exclude+=("$1") ;;
        esac
        shift
        ;;
    esac
  done

  typeset -a all_scripts filtered_scripts remove_list
  all_scripts=(${(f)"$(collect_scripts "$base_dir")"})

  remove_list=("${exclude[@]}" "${first_scripts[@]}" "${last_scripts[@]}")
  remove_list=(${remove_list:#})
  remove_list=(${(u)remove_list})

  filtered_scripts=(${(f)"$(
    printf "%s\n" "${all_scripts[@]}" | grep -vFxf <(printf "%s\n" "${remove_list[@]}")
  )"})

  if [[ "${ZSH_DEBUG:-0}" -ge 1 ]]; then
    printf "🗂 Loading group: %s\n" "$group_name"
    printf "🔽 Base: %s\n" "$base_dir"

    if (( ${#first_scripts[@]} > 0 )); then
      printf "⏫ First:\n"
      printf '   • %s\n' "${first_scripts[@]}"
    fi
    if (( ${#last_scripts[@]} > 0 )); then
      printf "⏬ Last:\n"
      printf '   • %s\n' "${last_scripts[@]}"
    fi
    if (( ${#exclude[@]} > 0 )); then
      printf "🚫 Exclude:\n"
      printf '   • %s\n' "${exclude[@]}"
    fi
  fi

  if [[ "${ZSH_DEBUG:-0}" -ge 2 ]]; then
    printf "📦 All collected scripts:\n"
    printf '   • %s\n' "${all_scripts[@]}"

    printf "✅ Scripts after filtering:\n"
    printf '   → %s\n' "${filtered_scripts[@]}"
  fi

  for file in "${first_scripts[@]}"; do
    source_file "$file"
  done

  for file in "${filtered_scripts[@]}"; do
    source_file "$file"
  done

  for file in "${last_scripts[@]}"; do
    source_file "$file"
  done
}
