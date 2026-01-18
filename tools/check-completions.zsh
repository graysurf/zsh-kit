#!/usr/bin/env -S zsh -f

setopt pipe_fail err_exit nounset

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr SCRIPT_NAME="${SCRIPT_PATH:t}"
typeset -gr SCRIPT_HINT="./tools/$SCRIPT_NAME"

# print_usage: Print CLI usage/help.
print_usage() {
  emulate -L zsh
  setopt pipe_fail nounset

  print -r -- "Usage: $SCRIPT_HINT [-h|--help]"
  print -r --
  print -r -- "Checks:"
  print -r -- "  - Completion modules have #compdef"
  print -r -- "  - Any commands bound via compdef also appear in #compdef"
  print -r -- "  - No _arguments-style specs (e.g. --flag[desc]) outside _arguments calls"
  print -r --
  print -r -- "Scope:"
  print -r -- "  - scripts/_completion/_*"
  print -r -- "  - scripts/_features/*/_completion/_*"
}

# repo_root_from_script: Resolve the repo root directory from this script path.
repo_root_from_script() {
  emulate -L zsh
  setopt pipe_fail nounset

  typeset script_dir='' root_dir=''
  script_dir="${SCRIPT_PATH:h}"
  root_dir="${script_dir:h}"
  print -r -- "$root_dir"
}

# list_completion_modules <root_dir>
# Print the completion module files (absolute paths).
list_completion_modules() {
  emulate -L zsh
  setopt pipe_fail nounset extendedglob null_glob

  typeset root_dir="$1"
  typeset -a files=()

  files+=("$root_dir"/scripts/_completion/_*(.N))
  files+=("$root_dir"/scripts/_features/*/_completion/_*(.N))

  print -rl -- "${files[@]}"
}

# array_contains <needle> <haystack...>
array_contains() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset needle="$1"
  shift
  typeset -a haystack=("$@")

  (( ${haystack[(I)$needle]} > 0 ))
}

# check_compdef_coverage <file>
# Ensure any commands bound via `compdef` are included in `#compdef`.
check_compdef_coverage() {
  emulate -L zsh
  setopt pipe_fail err_return nounset extendedglob

  typeset file="$1"
  typeset -a header_cmds=() compdef_cmds=()
  typeset line='' trimmed='' header_line=''
  typeset -i line_no=0

  while IFS=$'\n' read -r line; do
    line_no=$((line_no + 1))
    trimmed="${line##[[:space:]]#}"
    [[ -n "$trimmed" ]] || continue

    if [[ -z "$header_line" && "$trimmed" == '#compdef '* ]]; then
      header_line="$trimmed"
      typeset -a tokens=()
      tokens=(${(z)header_line})
      (( ${#tokens[@]} >= 2 )) || continue
      header_cmds=(${tokens[2,-1]})
      continue
    fi

    if [[ "$trimmed" == compdef\ * ]]; then
      typeset -a tokens=()
      tokens=(${(z)trimmed})
      (( ${#tokens[@]} >= 3 )) || continue
      compdef_cmds+=(${tokens[3,-1]})
    fi
  done < "$file"

  if [[ -z "$header_line" ]]; then
    print -u2 -r -- "completion-lint: missing #compdef: $file"
    return 1
  fi

  typeset -i failed=0
  typeset cmd=''
  for cmd in "${compdef_cmds[@]}"; do
    array_contains "$cmd" "${header_cmds[@]}" && continue
    failed=1
    print -u2 -r -- "completion-lint: compdef command missing from #compdef: $file ($cmd)"
  done

  return "$failed"
}

# check_no_arguments_specs_outside_arguments <file>
# Detect `_arguments`-style option specs outside `_arguments` invocations.
check_no_arguments_specs_outside_arguments() {
  emulate -L zsh
  setopt pipe_fail err_return nounset extendedglob

  typeset file="$1"
  typeset line='' trimmed='' line_rtrim=''
  typeset -i line_no=0 in_arguments=0 failed=0
  typeset -r arguments_style_option_re='--[^[:space:]]+\\[[^]]+\\]'

  while IFS=$'\n' read -r line; do
    line_no=$((line_no + 1))
    trimmed="${line##[[:space:]]#}"
    line_rtrim="${trimmed%%[[:space:]]#}"

    if [[ "$line_rtrim" == _arguments* ]]; then
      in_arguments=1
    fi

    if (( ! in_arguments )); then
      if [[ "$line_rtrim" =~ $arguments_style_option_re ]]; then
        failed=1
        print -u2 -r -- "completion-lint: _arguments-style spec outside _arguments: $file:$line_no"
        print -u2 -r -- "$line_rtrim"
      fi
    fi

    if (( in_arguments )); then
      if [[ -z "$line_rtrim" ]]; then
        continue
      fi
      if [[ "${line_rtrim[-1]}" != "\\" ]]; then
        in_arguments=0
      fi
    fi
  done < "$file"

  return "$failed"
}

# check_file <file>
check_file() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset file="$1"

  check_compdef_coverage "$file" || return 1
  check_no_arguments_specs_outside_arguments "$file" || return 1
  return 0
}

# main [args...]
main() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset -A opts=()
  zparseopts -D -E -A opts -- h -help || return 2

  if (( ${+opts[-h]} || ${+opts[--help]} )); then
    print_usage
    return 0
  fi

  typeset root_dir=''
  root_dir="$(repo_root_from_script)"

  typeset -a files=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && files+=("$line")
  done < <(list_completion_modules "$root_dir")

  if (( ${#files[@]} == 0 )); then
    print -u2 -r -- "completion-lint: no completion modules found"
    return 0
  fi

  typeset -i failed=0
  typeset file=''
  for file in "${files[@]}"; do
    check_file "$file" || failed=1
  done

  if (( failed )); then
    return 1
  fi

  return 0
}

main "$@"
