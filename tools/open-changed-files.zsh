#!/usr/bin/env -S zsh -f

setopt pipe_fail

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr SCRIPT_NAME="${SCRIPT_PATH:t}"

typeset -gi OCF_DEFAULT_MAX_FILES=5
typeset -gi OCF_GIT_ROOT_MAX_DEPTH=5
typeset -gi OCF_BATCH_SIZE=50

print_usage() {
  emulate -L zsh
  setopt pipe_fail

  print -r -- "Open changed files in VSCode."
  print -r -- ""
  print -r -- "Usage:"
  print -r -- "  $SCRIPT_NAME [--list|--git] [--dry-run] [--max-files N] [--] [files...]"
  print -r -- ""
  print -r -- "Modes:"
  print -r -- "  --list  Open explicit file paths (default; stdin fallback when no args)"
  print -r -- "  --git   Open changed files from git (staged + unstaged + untracked)"
  print -r -- ""
  print -r -- "Options:"
  print -r -- "  --dry-run       Print planned 'code ...' invocations (does not execute)"
  print -r -- "  --max-files N   Max files to open (default: ${OPEN_CHANGED_FILES_MAX_FILES:-$OCF_DEFAULT_MAX_FILES})"
  print -r -- "  -h, --help      Show this help"
  print -r -- ""
  print -r -- "Env:"
  print -r -- "  OPEN_CHANGED_FILES_SOURCE=list|git (default: ${OPEN_CHANGED_FILES_SOURCE:-list})"
  print -r -- "  OPEN_CHANGED_FILES_MAX_FILES=<n>     (default: $OCF_DEFAULT_MAX_FILES)"
}

_ocf::die_usage() {
  emulate -L zsh
  setopt pipe_fail

  typeset msg="${1-}"
  [[ -n "$msg" ]] && print -u2 -r -- "❌ $msg"
  print -u2 -r -- ""
  print_usage >&2
  return 2
}

_ocf::find_git_root_upwards() {
  emulate -L zsh
  setopt err_return nounset

  typeset dir="${1-}"
  typeset -i max_depth="${2:-$OCF_GIT_ROOT_MAX_DEPTH}"
  [[ -z "$dir" ]] && return 1

  dir="${dir:A}"

  typeset -i depth=0
  while (( depth <= max_depth )); do
    if [[ -e "$dir/.git" ]]; then
      print -r -- "$dir"
      return 0
    fi

    [[ "$dir" == "/" ]] && break
    dir="${dir:h}"
    (( ++depth ))
  done

  return 1
}

_ocf::collect_list_files() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset -a input=("$@")
  if (( ${#input[@]} == 0 )); then
    [[ -t 0 ]] && return 0
    typeset line=''
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      input+=("$line")
    done
  fi

  typeset -A seen=()
  typeset -a out=()

  typeset raw='' abs=''
  for raw in "${input[@]}"; do
    [[ -z "$raw" ]] && continue
    abs="${raw:A}"
    [[ -f "$abs" ]] || continue
    (( ${+seen[$abs]} )) && continue
    seen[$abs]=1
    out+=("$abs")
  done

  (( ${#out[@]} == 0 )) && return 0
  print -rl -- "${out[@]}"
}

_ocf::collect_git_files() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  command -v git >/dev/null 2>&1 || return 0
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0

  typeset repo_root=''
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || return 0
  repo_root="${repo_root:A}"

  typeset -a candidates=()
  candidates+=("${(@f)$(git diff --name-only --cached 2>/dev/null)}")
  candidates+=("${(@f)$(git diff --name-only 2>/dev/null)}")
  candidates+=("${(@f)$(git ls-files --others --exclude-standard 2>/dev/null)}")

  typeset -A seen=()
  typeset -a out=()

  typeset rel='' abs=''
  for rel in "${candidates[@]}"; do
    [[ -z "$rel" ]] && continue
    abs="${repo_root}/${rel}"
    abs="${abs:A}"
    [[ -f "$abs" ]] || continue
    (( ${+seen[$abs]} )) && continue
    seen[$abs]=1
    out+=("$abs")
  done

  (( ${#out[@]} == 0 )) && return 0
  print -rl -- "${out[@]}"
}

_ocf::print_code_invocation() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset workspace_root="$1"
  shift
  typeset -a files=("$@")

  typeset -a quoted_files=("${(@q)files}")
  typeset quoted_workspace="${(q)workspace_root}"

  print -r -- "code --new-window -- ${quoted_workspace} ${(j: :)quoted_files}"
}

_ocf::run_code_invocation() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  command -v code >/dev/null 2>&1 || return 0

  typeset workspace_root="$1"
  shift
  typeset -a files=("$@")

  code --new-window -- "$workspace_root" "${files[@]}"
}

main() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  zmodload zsh/zutil 2>/dev/null || {
    print -u2 -r -- "❌ zsh/zutil is required for zparseopts."
    return 1
  }

  typeset -A opts=()
  zparseopts -D -E -A opts -- h -help -list -git -dry-run -max-files: || return 2

  if (( ${+opts[-h]} || ${+opts[--help]} )); then
    print_usage
    return 0
  fi

  if (( ${+opts[--list]} && ${+opts[--git]} )); then
    _ocf::die_usage "Flags are mutually exclusive: --list and --git"
    return $?
  fi

  typeset mode="${OPEN_CHANGED_FILES_SOURCE:-list}"
  (( ${+opts[--list]} )) && mode='list'
  (( ${+opts[--git]} )) && mode='git'

  if [[ "$mode" != "list" && "$mode" != "git" ]]; then
    _ocf::die_usage "Invalid OPEN_CHANGED_FILES_SOURCE: $mode (expected: list|git)"
    return $?
  fi

  typeset -i dry_run=0
  (( ${+opts[--dry-run]} )) && dry_run=1

  typeset max_raw="${opts[--max-files]-}"
  [[ -z "$max_raw" ]] && max_raw="${OPEN_CHANGED_FILES_MAX_FILES:-$OCF_DEFAULT_MAX_FILES}"
  [[ "$max_raw" != <-> ]] && { _ocf::die_usage "Invalid --max-files: $max_raw"; return $?; }
  typeset -i max_files="$max_raw"
  (( max_files < 0 )) && { _ocf::die_usage "--max-files must be >= 0"; return $?; }
  (( max_files == 0 )) && return 0

  if (( !dry_run )); then
    command -v code >/dev/null 2>&1 || return 0
  fi

  typeset -a files=()
  if [[ "$mode" == "list" ]]; then
    files=("${(@f)$(_ocf::collect_list_files "$@")}")
  else
    files=("${(@f)$(_ocf::collect_git_files)}")
  fi

  (( ${#files[@]} == 0 )) && return 0
  files=("${files[@]:0:max_files}")

  typeset pwd_workspace="${PWD:A}"
  typeset -A groups=()
  typeset -a workspace_order=()

  typeset file='' workspace=''
  for file in "${files[@]}"; do
    workspace="$(_ocf::find_git_root_upwards "${file:h}" "$OCF_GIT_ROOT_MAX_DEPTH" || true)"
    [[ -z "$workspace" ]] && workspace="$pwd_workspace"

    if [[ -z "${groups[$workspace]-}" ]]; then
      groups[$workspace]=''
      workspace_order+=("$workspace")
    fi
    groups[$workspace]+="$file"$'\n'
  done

  typeset -i batch_size="$OCF_BATCH_SIZE"
  typeset -i idx=0
  typeset -a ws_files=() batch=()
  for workspace in "${workspace_order[@]}"; do
    ws_files=("${(@f)${groups[$workspace]}}")
    idx=0
    while (( idx < ${#ws_files[@]} )); do
      batch=("${ws_files[@]:idx:batch_size}")
      idx=$(( idx + batch_size ))

      if (( dry_run )); then
        _ocf::print_code_invocation "$workspace" "${batch[@]}"
      else
        _ocf::run_code_invocation "$workspace" "${batch[@]}"
      fi
    done
  done

  return 0
}

main "$@"

