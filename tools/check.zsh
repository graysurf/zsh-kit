#!/usr/bin/env -S zsh -f

setopt pipe_fail err_exit nounset

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr SCRIPT_NAME="${SCRIPT_PATH:t}"
typeset -gr SCRIPT_HINT="./tools/$SCRIPT_NAME"

# print_usage: Print CLI usage/help for tools/check.zsh.
print_usage() {
  emulate -L zsh
  setopt pipe_fail nounset

  print -r -- "Usage: $SCRIPT_HINT [-h|--help] [-s|--smoke] [-b|--bash] [--semgrep] [-a|--all]"
  print -r -- ""
  print -r -- "Checks:"
  print -r -- "  (default) zsh syntax: zsh -n on repo zsh + zsh-style *.sh (excluding plugins/)"
  print -r -- "  --smoke: load .zshrc (and .zprofile) in isolated ZDOTDIR/cache; fails if any stderr is emitted"
  print -r -- "  --bash : bash -n on bash scripts; runs ShellCheck if installed"
  print -r -- "  --semgrep: semgrep scan (bash/zsh) with JSON output under ./out/semgrep/"
  print -r -- ""
  print -r -- "Examples:"
  print -r -- "  $SCRIPT_HINT"
  print -r -- "  $SCRIPT_HINT --smoke"
  print -r -- "  $SCRIPT_HINT --bash"
  print -r -- "  $SCRIPT_HINT --semgrep"
  print -r -- "  $SCRIPT_HINT --all"
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

# is_zsh_style_sh_file <file>
# Decide whether a *.sh file should be checked with `zsh -n`.
# Usage: is_zsh_style_sh_file <file>
is_zsh_style_sh_file() {
  emulate -L zsh
  setopt pipe_fail nounset

  typeset file="$1" first_line=''
  IFS=$'\n' read -r first_line < "$file" || first_line=''

  if [[ "$first_line" == '#!'* ]]; then
    [[ "$first_line" == *zsh* ]] && return 0
    [[ "$first_line" == *bash* ]] && return 1
    [[ "$first_line" == *'/sh'* || "$first_line" == *' env sh'* ]] && return 1
    return 1
  fi

  # No shebang: in this repo, these are typically sourced by zsh.
  return 0
}

# check_zsh_syntax <root_dir>
# Run `zsh -n` across first-party zsh files (and zsh-style *.sh files).
# Usage: check_zsh_syntax <root_dir>
check_zsh_syntax() {
  emulate -L zsh
  setopt pipe_fail nounset extendedglob null_glob

  typeset root_dir="$1"
  typeset -i failed=0
  typeset -a zsh_files=() sh_files=()

  [[ -f "$root_dir/.zshenv" ]] && zsh_files+=("$root_dir/.zshenv")
  [[ -f "$root_dir/.zshrc" ]] && zsh_files+=("$root_dir/.zshrc")
  [[ -f "$root_dir/.zprofile" ]] && zsh_files+=("$root_dir/.zprofile")
  zsh_files+=("$root_dir"/*.zsh(.N))

  zsh_files+=("$root_dir"/bootstrap/**/*.zsh(.N))
  zsh_files+=("$root_dir"/scripts/**/*.zsh(.N))
  zsh_files+=("$root_dir"/tools/**/*.zsh(.N))
  zsh_files+=("$root_dir"/.private/**/*.zsh(.N))

  sh_files+=("$root_dir"/.private/**/*.sh(.N))

  for file in "${zsh_files[@]}"; do
    if ! zsh -n -- "$file"; then
      print -u2 -r -- "zsh -n failed: $file"
      failed=1
    fi
  done

  for file in "${sh_files[@]}"; do
    is_zsh_style_sh_file "$file" || continue
    if ! zsh -n -- "$file"; then
      print -u2 -r -- "zsh -n failed: $file"
      failed=1
    fi
  done

  return "$failed"
}

# check_smoke_load <root_dir>
# Smoke-load `.zshrc` (and `.zprofile`) in an isolated environment; treat any stderr as failure.
# Usage: check_smoke_load <root_dir>
check_smoke_load() {
  emulate -L zsh
  setopt pipe_fail nounset

  typeset root_dir="$1"
  typeset tmp_dir=''
  typeset stderr_file=''
  typeset -i smoke_exit_code=0

  tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t zsh-kit-check.XXXXXX)"
  stderr_file="$tmp_dir/smoke.stderr"
  : >| "$stderr_file"

  {
    ZDOTDIR="$root_dir" \
      ZSH_CACHE_DIR="$tmp_dir" \
      PLUGIN_FETCH_DRY_RUN=true \
      _LOGIN_WEATHER_EXECUTED=1 \
      _LOGIN_QUOTE_EXECUTED=1 \
      zsh -f -ic 'source "$ZDOTDIR/.zshrc"; exit' 2>> "$stderr_file"
    smoke_exit_code=$?

    ZDOTDIR="$root_dir" \
      ZSH_CACHE_DIR="$tmp_dir" \
      PLUGIN_FETCH_DRY_RUN=true \
      _LOGIN_WEATHER_EXECUTED=1 \
      _LOGIN_QUOTE_EXECUTED=1 \
      zsh -f -ic 'source "$ZDOTDIR/.zprofile"; source "$ZDOTDIR/.zshrc"; exit' 2>> "$stderr_file" || smoke_exit_code=$?

    if [[ -s "$stderr_file" ]]; then
      print -u2 -r -- "smoke: stderr emitted (treated as failure)"
      command cat -- "$stderr_file" >&2
      smoke_exit_code=1
    fi

    return "$smoke_exit_code"
  } always {
    rm -rf -- "$tmp_dir"
  }
}

# check_bash_scripts <root_dir>
# Run `bash -n` (and ShellCheck when available) on bash scripts under `.private/`.
# Usage: check_bash_scripts <root_dir>
check_bash_scripts() {
  emulate -L zsh
  setopt pipe_fail nounset extendedglob null_glob

  typeset root_dir="$1"
  typeset -i failed=0
  typeset -a sh_files=() bash_files=()

  sh_files+=("$root_dir"/.private/**/*.sh(.N))

  for file in "${sh_files[@]}"; do
    typeset first_line=''
    IFS=$'\n' read -r first_line < "$file" || first_line=''
    [[ "$first_line" == '#!'*bash* ]] || continue
    bash_files+=("$file")
  done

  if (( ${#bash_files[@]} == 0 )); then
    return 0
  fi

  for file in "${bash_files[@]}"; do
    if ! bash -n -- "$file"; then
      print -u2 -r -- "bash -n failed: $file"
      failed=1
    fi

    if command -v shellcheck >/dev/null 2>&1; then
      if ! shellcheck -s bash -- "$file"; then
        print -u2 -r -- "shellcheck failed: $file"
        failed=1
      fi
    fi
  done

  return "$failed"
}

# check_semgrep_scan <root_dir>
# Run Semgrep scan via tools/semgrep-scan.zsh (writes JSON output to out/semgrep).
# Usage: check_semgrep_scan <root_dir>
check_semgrep_scan() {
  emulate -L zsh
  setopt pipe_fail nounset

  typeset root_dir="$1"
  typeset semgrep_scan_script="$root_dir/tools/semgrep-scan.zsh"

  if [[ ! -f "$semgrep_scan_script" ]]; then
    print -u2 -r -- "semgrep: missing scan script: $semgrep_scan_script"
    return 1
  fi

  typeset semgrep_json=''
  semgrep_json="$(zsh -f -- "$semgrep_scan_script")" || return 1
  if [[ -n "$semgrep_json" ]]; then
    print -r -- "$semgrep_json"
    semgrep_summary "$root_dir" "$semgrep_json"
  fi
  return 0
}

# semgrep_summary <root_dir> <json_path>
# Print a short Semgrep findings summary to stderr.
semgrep_summary() {
  emulate -L zsh
  setopt pipe_fail nounset

  typeset root_dir="$1"
  typeset json_path="$2"
  typeset limit="${SEMGREP_SUMMARY_LIMIT:-5}"

  if [[ -z "$json_path" ]]; then
    return 0
  fi

  typeset python_bin="$root_dir/.venv/bin/python"
  if [[ ! -x "$python_bin" ]]; then
    python_bin="$(command -v python3 || true)"
  fi
  if [[ -z "$python_bin" ]]; then
    print -u2 -r -- "warning: python3 not found; skipping semgrep summary"
    return 0
  fi

  "$python_bin" - "$json_path" "$limit" <<'PY'
import json
import sys

path = sys.argv[1]
try:
    limit = int(sys.argv[2])
except Exception:
    limit = 5

try:
    with open(path, "r", encoding="utf-8") as handle:
        data = json.load(handle)
except Exception as exc:
    sys.stderr.write(f"semgrep: failed to read {path}: {exc}\n")
    sys.exit(0)

results = data.get("results") or []
count = len(results)
if count == 0:
    sys.stderr.write("semgrep: 0 findings\n")
    sys.exit(0)

sys.stderr.write(f"semgrep: {count} findings (showing up to {limit})\n")
for result in results[:limit]:
    check_id = result.get("check_id") or "unknown"
    path = result.get("path") or "unknown"
    start = result.get("start") or {}
    line = start.get("line")
    location = f"{path}:{line}" if line else path
    message = (result.get("extra") or {}).get("message") or ""
    message = " ".join(message.split())
    if message:
        sys.stderr.write(f"- {check_id} {location} {message}\n")
    else:
        sys.stderr.write(f"- {check_id} {location}\n")
PY
}

# main [args...]
# CLI entrypoint for the repo check script.
# Usage: main [args...]
main() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset -A opts=()
  # NOTE: In zparseopts, `-help` matches `--help` (GNU-style long options).
  zparseopts -D -E -A opts -- h -help s -smoke b -bash -semgrep a -all || return 2

  if (( ${+opts[-h]} || ${+opts[--help]} )); then
    print_usage
    return 0
  fi

  typeset -i run_smoke=0 run_bash=0 run_semgrep=0
  (( ${+opts[-s]} || ${+opts[--smoke]} )) && run_smoke=1
  (( ${+opts[-b]} || ${+opts[--bash]} )) && run_bash=1
  (( ${+opts[--semgrep]} )) && run_semgrep=1
  if (( ${+opts[-a]} || ${+opts[--all]} )); then
    run_smoke=1
    run_bash=1
    run_semgrep=1
  fi

  typeset root_dir=''
  root_dir="$(repo_root_from_script)"

  check_zsh_syntax "$root_dir" || return 1
  if (( run_smoke )); then
    check_smoke_load "$root_dir" || return 1
  fi
  if (( run_bash )); then
    check_bash_scripts "$root_dir" || return 1
  fi
  if (( run_semgrep )); then
    check_semgrep_scan "$root_dir" || return 1
  fi

  return 0
}

main "$@"
