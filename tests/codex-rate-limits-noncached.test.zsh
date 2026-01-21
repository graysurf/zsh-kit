#!/usr/bin/env -S zsh -f

setopt pipe_fail nounset

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr TEST_DIR="${SCRIPT_PATH:h}"
typeset -gr REPO_ROOT="${TEST_DIR:h}"

fail() {
  emulate -L zsh
  setopt pipe_fail nounset

  print -u2 -r -- "FAIL: $*"
  exit 1
}

assert_eq() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset expected="$1" actual="$2" context="$3"
  if [[ "$actual" != "$expected" ]]; then
    print -u2 -r -- "Expected: $expected"
    print -u2 -r -- "Actual  : $actual"
    print -u2 -r -- "Context : $context"
    return 1
  fi
  return 0
}

{
  typeset tmp_root=''
  tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/codex-rate-limits-noncached-test.XXXXXX" 2>/dev/null)" || tmp_root=''
  [[ -n "${tmp_root}" && -d "${tmp_root}" ]] || fail "failed to create temp dir"
  trap "command rm -rf -- ${(qq)tmp_root} 2>/dev/null || true" EXIT

  typeset cache_root="${tmp_root}/cache"
  typeset secret_dir="${tmp_root}/secrets"
  mkdir -p -- "${cache_root}" "${secret_dir}" || fail "failed to create temp directories"

  typeset secret_file="${secret_dir}/acc_a.json"
  {
    print -r -- '{'
    print -r -- '  "tokens": {'
    print -r -- '    "access_token": "dummy-access-token",'
    print -r -- '    "account_id": "dummy-account-id"'
    print -r -- '  }'
    print -r -- '}'
  } >| "${secret_file}" || fail "failed to write secret: ${secret_file}"

  typeset fixed_now_epoch=1700000000
  typeset primary_reset_epoch=$(( fixed_now_epoch + 3600 ))
  typeset weekly_reset_epoch=$(( fixed_now_epoch + 7200 ))

  source "${REPO_ROOT}/bootstrap/00-preload.zsh"
  export CODEX_SECRET_DIR="${secret_dir}"
  export ZSH_CACHE_DIR="${cache_root}"
  source "${REPO_ROOT}/scripts/_features/codex/codex-secret.zsh"

  curl() {
    emulate -L zsh
    setopt localoptions nounset

    typeset out_file=''
    typeset -a args=("$@")
    typeset -i i=1
    while (( i <= $#args )); do
      case "${args[$i]-}" in
        -o)
          i=$(( i + 1 ))
          out_file="${args[$i]-}"
          ;;
      esac
      i=$(( i + 1 ))
    done

    [[ -n "${out_file}" ]] || return 2

    {
      print -r -- '{'
      print -r -- '  "rate_limit": {'
      print -r -- '    "primary_window": {'
      print -r -- '      "limit_window_seconds": 3600,'
      print -r -- '      "used_percent": 46,'
      print -r -- "      \"reset_at\": ${primary_reset_epoch}"
      print -r -- '    },'
      print -r -- '    "secondary_window": {'
      print -r -- '      "limit_window_seconds": 604800,'
      print -r -- '      "used_percent": 37,'
      print -r -- "      \"reset_at\": ${weekly_reset_epoch}"
      print -r -- '    }'
      print -r -- '  }'
      print -r -- '}'
    } >| "${out_file}" || return 3

    print -r -- '200'
    return 0
  }

  typeset reset=''
  reset="$(_codex_epoch_format_local_datetime "${weekly_reset_epoch}" 2>/dev/null)" || reset=''
  [[ -n "${reset}" ]] || fail "failed to format weekly reset time"

  typeset output='' expected='' rc=0
  output="$(codex-rate-limits --one-line acc_a.json 2>&1)"
  rc=$?

  assert_eq 0 "${rc}" "codex-rate-limits --one-line should exit 0" || fail "${output}"

  expected="acc_a 1h:54% W:63% ${reset}"
  assert_eq "${expected}" "${output}" "codex-rate-limits --one-line should print expected summary" || fail "${output}"

  typeset -a wham_files=()
  wham_files=( "${secret_dir}"/wham.usage.*(N) )
  if (( ${#wham_files[@]} > 0 )); then
    fail "expected wham.usage temp files to be cleaned up"
  fi

  print -r -- "OK"
}
