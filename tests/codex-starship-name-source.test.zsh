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
  tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/codex-starship-name-source-test.XXXXXX" 2>/dev/null)" || tmp_root=''
  [[ -n "${tmp_root}" && -d "${tmp_root}" ]] || fail "failed to create temp dir"
  trap "command rm -rf -- ${(qq)tmp_root} 2>/dev/null || true" EXIT

  typeset cache_root="${tmp_root}/cache"
  typeset cache_dir="${cache_root}/codex/starship-rate-limits"
  typeset secret_dir="${tmp_root}/secrets"
  mkdir -p -- "${cache_dir}" "${secret_dir}" || fail "failed to create temp directories"

  typeset auth_file="${tmp_root}/auth.json"
  typeset payload_b64='eyJlbWFpbCI6ImFsaWNlQGV4YW1wbGUuY29tIiwic3ViIjoic3ViLTEyMyJ9'
  typeset token="a.${payload_b64}.b"
  {
    print -r -- '{'
    print -r -- '  "tokens": {'
    print -r -- "    \"id_token\": \"${token}\""
    print -r -- '  }'
    print -r -- '}'
  } >| "${auth_file}" || fail "failed to write auth file"

  typeset -i fixed_now_epoch=1700000000
  date() {
    if [[ "$#" -eq 1 && "$1" == "+%s" ]]; then
      print -r -- "${fixed_now_epoch}"
      return 0
    fi
    command date "$@"
  }

  source "${REPO_ROOT}/bootstrap/00-preload.zsh"
  source "${REPO_ROOT}/scripts/_features/codex/codex-starship.zsh"

  export NO_COLOR=1
  export CODEX_STARSHIP_ENABLED=true
  export CODEX_AUTH_FILE="${auth_file}"
  export CODEX_SECRET_DIR="${secret_dir}"
  export ZSH_CACHE_DIR="${cache_root}"

  typeset auth_hash='' key='' cache_file='' weekly_reset_epoch='' weekly_reset_time=''
  auth_hash="$(_codex_starship_sha256 "${auth_file}" 2>/dev/null)" || auth_hash=''
  [[ -n "$auth_hash" ]] || fail "failed to sha256 auth file"
  key="auth_${auth_hash:l}"
  cache_file="${cache_dir}/${key}.kv"

  weekly_reset_epoch=$(( fixed_now_epoch + 3600 ))
  weekly_reset_time="$(_codex_starship_epoch_utc_format "${weekly_reset_epoch}" '%m-%d %H:%M' 2>/dev/null)" || weekly_reset_time=''
  [[ -n "$weekly_reset_time" ]] || fail "failed to format weekly reset time"

  {
    print -r -- "fetched_at=${fixed_now_epoch}"
    print -r -- 'weekly_remaining=80'
    print -r -- "weekly_reset_epoch=${weekly_reset_epoch}"
  } >| "${cache_file}" || fail "failed to write cache file"

  unset CODEX_STARSHIP_NAME_SOURCE CODEX_STARSHIP_SHOW_FULL_EMAIL_ENABLED
  export CODEX_STARSHIP_SHOW_FALLBACK_NAME_ENABLED=false

  typeset output='' expected=''
  output="$(codex-starship --no-5h --ttl 1h --time-format '%m-%d %H:%M' 2>/dev/null)"
  expected="W:80% ${weekly_reset_time}"
  assert_eq "${expected}" "${output}" "default should omit name when secrets do not match and fallback is disabled" || fail "${output}"

  export CODEX_STARSHIP_SHOW_FALLBACK_NAME_ENABLED=true
  output="$(codex-starship --no-5h --ttl 1h --time-format '%m-%d %H:%M' 2>/dev/null)"
  expected="alice W:80% ${weekly_reset_time}"
  assert_eq "${expected}" "${output}" "fallback name should prefer email local-part" || fail "${output}"

  export CODEX_STARSHIP_SHOW_FALLBACK_NAME_ENABLED=false
  export CODEX_STARSHIP_NAME_SOURCE=email
  output="$(codex-starship --no-5h --ttl 1h --time-format '%m-%d %H:%M' 2>/dev/null)"
  expected="alice W:80% ${weekly_reset_time}"
  assert_eq "${expected}" "${output}" "name_source=email should show email even when fallback is disabled" || fail "${output}"

  export CODEX_STARSHIP_SHOW_FULL_EMAIL_ENABLED=true
  output="$(codex-starship --no-5h --ttl 1h --time-format '%m-%d %H:%M' 2>/dev/null)"
  expected="alice@example.com W:80% ${weekly_reset_time}"
  assert_eq "${expected}" "${output}" "show_full_email should print full email" || fail "${output}"

  print -r -- "OK"
}

