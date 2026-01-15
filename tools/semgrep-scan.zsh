#!/usr/bin/env -S zsh -f

setopt pipe_fail err_exit nounset

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr SCRIPT_NAME="${SCRIPT_PATH:t}"
typeset -gr SCRIPT_HINT="./tools/$SCRIPT_NAME"

# print_usage: Print CLI usage/help for tools/semgrep-scan.zsh.
print_usage() {
  emulate -L zsh
  setopt pipe_fail nounset

  print -r -- "Usage:"
  print -r -- "  $SCRIPT_HINT [--profile <local|shell>] [--target <path>] [--] [semgrep args...]"
  print -r -- ""
  print -r -- "Runs Semgrep with repo-local rules plus selected Semgrep Registry packs."
  print -r -- "Writes JSON output to \$CODEX_HOME/out/semgrep/ (or ./out/semgrep/) and prints the JSON path to stdout."
  print -r -- ""
  print -r -- "Profiles:"
  print -r -- "  local: .semgrep.yaml only"
  print -r -- "  shell: .semgrep.yaml + p/supply-chain + p/command-injection + p/secrets (restricts to bash/zsh files)"
  print -r -- ""
  print -r -- "Default targets (when --target is not set):"
  print -r -- "  .zshenv .zprofile .zshrc install-tools.zsh bootstrap/ scripts/ tools/ .private/ (if present)"
  print -r -- ""
  print -r -- "Examples:"
  print -r -- "  $SCRIPT_HINT"
  print -r -- "  $SCRIPT_HINT --profile shell"
  print -r -- "  $SCRIPT_HINT --target scripts"
  print -r -- "  $SCRIPT_HINT -- --exclude tests"
}

# repo_root_from_script: Resolve the repo root directory from this script path.
repo_root_from_script() {
  emulate -L zsh
  setopt pipe_fail nounset

  typeset script_path='' script_dir='' root_dir=''
  script_path="$SCRIPT_PATH"
  script_dir="${script_path:h}"
  root_dir="${script_dir:h}"
  print -r -- "$root_dir"
}

# main [args...]
# CLI entrypoint for the Semgrep scan helper.
# Usage: main [args...]
main() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset -A opts=()
  # NOTE: In zparseopts, `-help` matches `--help` (GNU-style long options).
  zparseopts -D -E -A opts -- h -help -profile: -target: || return 2

  if (( ${+opts[-h]} || ${+opts[--help]} )); then
    print_usage
    return 0
  fi

  typeset profile='shell'
  (( ${+opts[--profile]} )) && profile="${opts[--profile]}"

  typeset target=''
  (( ${+opts[--target]} )) && target="${opts[--target]}"

  if (( $# > 0 )) && [[ "${1-}" == '--' ]]; then
    shift
  fi
  typeset -a pass_args=("$@")

  typeset repo_root=''
  repo_root="$(repo_root_from_script)"
  cd "$repo_root" || return 1

  typeset semgrep_bin="$repo_root/.venv/bin/semgrep"
  if [[ ! -x "$semgrep_bin" ]]; then
    semgrep_bin="$(command -v semgrep || true)"
  fi
  if [[ -z "$semgrep_bin" ]]; then
    print -u2 -r -- "error: semgrep not found"
    print -u2 -r -- "hint: install semgrep (or create $repo_root/.venv with semgrep installed)"
    return 1
  fi

  typeset config="$repo_root/.semgrep.yaml"
  if [[ ! -f "$config" ]]; then
    print -u2 -r -- "error: missing semgrep config: $config"
    return 1
  fi

  typeset -a configs=(--config "$config")

  case "$profile" in
    local)
      ;;
    shell)
      for cfg in p/supply-chain p/command-injection p/secrets; do
        configs+=(--config "$cfg")
      done
      ;;
    *)
      print -u2 -r -- "error: unknown --profile: $profile (expected local|shell)"
      return 2
      ;;
  esac

  typeset -a semgrep_args=()
  semgrep_args+=('--include=*.sh')
  semgrep_args+=('--include=*.zsh')
  semgrep_args+=('--include=.zshenv')
  semgrep_args+=('--include=.zprofile')
  semgrep_args+=('--include=.zshrc')
  semgrep_args+=('--scan-unknown-extensions')
  semgrep_args+=("${pass_args[@]}")

  typeset -a targets=()
  if [[ -n "$target" ]]; then
    targets+=("$target")
  else
    typeset file='' dir=''
    for file in .zshenv .zprofile .zshrc install-tools.zsh; do
      [[ -f "$repo_root/$file" ]] && targets+=("$file")
    done
    for dir in bootstrap scripts tools .private; do
      [[ -d "$repo_root/$dir" ]] && targets+=("$dir")
    done
  fi

  if (( ${#targets[@]} == 0 )); then
    print -u2 -r -- "error: no targets found"
    return 1
  fi

  typeset out_root="${CODEX_HOME:-$repo_root}"
  typeset out_dir="$out_root/out/semgrep"
  command mkdir -p -- "$out_dir" || return 1

  typeset repo_name="${repo_root:t}"
  typeset out_json="$out_dir/semgrep-${repo_name}-$(date +%Y%m%d-%H%M%S).json"

  typeset -i rc=0
  if "$semgrep_bin" scan \
    "${configs[@]}" \
    --json \
    --metrics=off \
    --disable-version-check \
    "${semgrep_args[@]}" \
    "${targets[@]}" >| "$out_json"; then
    rc=0
  else
    rc=$?
  fi

  if (( rc != 0 )); then
    print -u2 -r -- "error: semgrep scan failed (exit=$rc)"
    print -u2 -r -- "note: output json (may be partial): $out_json"
    return "$rc"
  fi

  print -r -- "$out_json"
  return 0
}

main "$@"

