# Only define once
typeset -f source_file >/dev/null && return

# source_file <file> [label]
# Source a file and print load timing (always prints a timing line).
# Usage: source_file <path> [label]
# Notes:
# - No-ops (returns 0) when <path> is empty or missing.
# - Returns the exit status of `source` for existing files.
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

# source_file_warn_missing <file>
# Source a single file; warn to stderr when the file is missing.
# Usage: source_file_warn_missing <path>
source_file_warn_missing() {
  typeset file="$1"

  if [[ -f "$file" ]]; then
    source_file "$file"
  else
    printf "⚠️  File not found: %s\n" "$file" >&2
  fi
}

# collect_scripts <dir...>
# Print all `.sh` and `.zsh` files under the given directories (recursive).
# Usage: collect_scripts <dir...>
# Output: newline-separated file paths.
collect_scripts() {
  typeset dir=''
  for dir in "$@"; do
    print -rl -- "$dir"/**/*.sh(N) "$dir"/**/*.zsh(N)
  done
}

# script_is_in_underscored_path <base_dir> <file>
# Return 0 if <file> is under an underscored path segment (folder or basename).
# Notes:
# - Paths are checked relative to <base_dir>, so underscores outside the base directory don't count.
script_is_in_underscored_path() {
  typeset base_dir="$1"
  typeset file="$2"

  base_dir="${base_dir%/}"
  typeset base_abs="${base_dir:A}"
  typeset file_abs="${file:A}"

  [[ "${base_abs:t}" == _* ]] && return 0

  typeset rel="$file_abs"
  if [[ "$file_abs" == "$base_abs"/* ]]; then
    rel="${file_abs#$base_abs/}"
  fi

  typeset -a parts=(${(s:/:)rel})
  typeset part=''
  for part in "${parts[@]}"; do
    [[ "$part" == _* ]] && return 0
  done

  return 1
}

# load_script_group <group_name> <base_dir> [exclude...]
# Load scripts under a directory with timing output.
# Usage: load_script_group <group_name> <base_dir> [exclude...]
# Notes:
# - Respects `ZSH_DEBUG` for verbose output.
load_script_group() {
  typeset group_name="$1"
  typeset base_dir="$2"
  shift 2
  typeset -a exclude=("$@")

  typeset -a all_scripts=() filtered_scripts=() skipped_scripts=() remove_list=()
  typeset file='' ex=''
  all_scripts=(${(f)"$(collect_scripts "$base_dir")"})

  skipped_scripts=()
  for file in "${all_scripts[@]}"; do
    script_is_in_underscored_path "$base_dir" "$file" && skipped_scripts+=("$file")
  done

  if [[ "${ZSH_DEBUG:-0}" -ge 1 ]]; then
    printf "🗂 Loading group: %s\n" "$group_name"
    printf "🔽 Base: %s\n" "$base_dir"
    if (( ${#skipped_scripts[@]} > 0 )); then
      printf "⏭ Skipped (_* folder/file):\n"
      printf '   • %s\n' "${skipped_scripts[@]}"
    fi
    printf "🚫 Exclude:\n"
    for ex in "${exclude[@]}"; do
      printf "   - %s\n" "$ex"
    done
  fi

  if [[ "${ZSH_DEBUG:-0}" -ge 2 ]]; then
    printf "📦 All collected scripts:\n"
    printf '   • %s\n' "${all_scripts[@]}"
  fi

  remove_list=("${exclude[@]}" "${skipped_scripts[@]}")
  remove_list=(${remove_list:#})
  remove_list=(${(u)remove_list})

  filtered_scripts=(${(f)"$(
    printf "%s\n" "${all_scripts[@]}" | grep -vFxf <(printf "%s\n" "${remove_list[@]}")
  )"})

  if [[ "${ZSH_DEBUG:-0}" -ge 2 ]]; then
    printf "✅ Scripts after filtering:\n"
    printf '   → %s\n' "${filtered_scripts[@]}"
  fi

  for file in "${filtered_scripts[@]}"; do
    source_file "$file"
  done
}

# load_script_group_ordered <group-name> <base-dir> [--first <file...>] [--last <file...>] [--exclude <file...>] [--] [<exclude...>]
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
  typeset file=''

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

  typeset -a all_scripts=() filtered_scripts=() remove_list=()
  all_scripts=(${(f)"$(collect_scripts "$base_dir")"})

  typeset -A pinned_set=()
  typeset -a pinned_scripts=()
  pinned_scripts=("${first_scripts[@]}" "${last_scripts[@]}")
  pinned_scripts=(${pinned_scripts:#})
  pinned_scripts=(${(u)pinned_scripts})
  for file in "${pinned_scripts[@]}"; do
    pinned_set[${file:A}]=1
  done

  typeset -a skipped_scripts=()
  for file in "${all_scripts[@]}"; do
    script_is_in_underscored_path "$base_dir" "$file" || continue
    [[ -n ${pinned_set[${file:A}]-} ]] && continue
    skipped_scripts+=("$file")
  done

  remove_list=("${exclude[@]}" "${first_scripts[@]}" "${last_scripts[@]}")
  remove_list+=("${skipped_scripts[@]}")
  remove_list=(${remove_list:#})
  remove_list=(${(u)remove_list})

  filtered_scripts=(${(f)"$(
    printf "%s\n" "${all_scripts[@]}" | grep -vFxf <(printf "%s\n" "${remove_list[@]}")
  )"})

  if [[ "${ZSH_DEBUG:-0}" -ge 1 ]]; then
    printf "🗂 Loading group: %s\n" "$group_name"
    printf "🔽 Base: %s\n" "$base_dir"
    if (( ${#skipped_scripts[@]} > 0 )); then
      printf "⏭ Skipped (_* folder/file):\n"
      printf '   • %s\n' "${skipped_scripts[@]}"
    fi

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
