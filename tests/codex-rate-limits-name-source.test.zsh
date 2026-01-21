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

assert_contains() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset haystack="$1" needle="$2" context="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    print -u2 -r -- "Missing substring: $needle"
    print -u2 -r -- "Context         : $context"
    return 1
  fi
  return 0
}

{
  typeset tmp_root=''
  tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/codex-rate-limits-name-source-test.XXXXXX" 2>/dev/null)" || tmp_root=''
  [[ -n "${tmp_root}" && -d "${tmp_root}" ]] || fail "failed to create temp dir"
  trap "command rm -rf -- ${(qq)tmp_root} 2>/dev/null || true" EXIT

  typeset cache_root="${tmp_root}/cache"
  typeset cache_dir="${cache_root}/codex/starship-rate-limits"
  typeset secret_dir="${tmp_root}/secrets"
  mkdir -p -- "${cache_dir}" "${secret_dir}" || fail "failed to create temp directories"

  typeset payload_a='eyJlbWFpbCI6ImFsaWNlQGV4YW1wbGUuY29tIiwic3ViIjoic3ViLTEyMyJ9'
  typeset payload_b='eyJlbWFpbCI6ImJvYkBleGFtcGxlLmNvbSIsInN1YiI6InN1Yi00NTYifQ'
  typeset token_a="a.${payload_a}.b"
  typeset token_b="a.${payload_b}.b"

  typeset secret_a="${secret_dir}/acc_a.json"
  typeset secret_b="${secret_dir}/acc_b.json"
  {
    print -r -- '{'
    print -r -- '  "tokens": {'
    print -r -- "    \"id_token\": \"${token_a}\""
    print -r -- '  }'
    print -r -- '}'
  } >| "${secret_a}" || fail "failed to write secret: ${secret_a}"
  {
    print -r -- '{'
    print -r -- '  "tokens": {'
    print -r -- "    \"id_token\": \"${token_b}\""
    print -r -- '  }'
    print -r -- '}'
  } >| "${secret_b}" || fail "failed to write secret: ${secret_b}"

  typeset fixed_now_epoch=1700000000
  typeset weekly_reset_epoch_a=$(( fixed_now_epoch + 3600 ))
  typeset weekly_reset_epoch_b=$(( fixed_now_epoch + 7200 ))

  {
    print -r -- "fetched_at=${fixed_now_epoch}"
    print -r -- 'non_weekly_label=5h'
    print -r -- 'non_weekly_remaining=54'
    print -r -- "non_weekly_reset_epoch=${weekly_reset_epoch_a}"
    print -r -- 'weekly_remaining=63'
    print -r -- "weekly_reset_epoch=${weekly_reset_epoch_a}"
  } >| "${cache_dir}/acc_a.kv" || fail "failed to write cache file acc_a.kv"
  {
    print -r -- "fetched_at=${fixed_now_epoch}"
    print -r -- 'non_weekly_label=5h'
    print -r -- 'non_weekly_remaining=42'
    print -r -- "non_weekly_reset_epoch=${weekly_reset_epoch_b}"
    print -r -- 'weekly_remaining=77'
    print -r -- "weekly_reset_epoch=${weekly_reset_epoch_b}"
  } >| "${cache_dir}/acc_b.kv" || fail "failed to write cache file acc_b.kv"

  source "${REPO_ROOT}/bootstrap/00-preload.zsh"
  export CODEX_SECRET_DIR="${secret_dir}"
  export ZSH_CACHE_DIR="${cache_root}"
  source "${REPO_ROOT}/scripts/_features/codex/codex-secret.zsh"

  typeset reset_a='' reset_b=''
  reset_a="$(_codex_epoch_format_local_datetime "${weekly_reset_epoch_a}" 2>/dev/null)" || reset_a=''
  reset_b="$(_codex_epoch_format_local_datetime "${weekly_reset_epoch_b}" 2>/dev/null)" || reset_b=''
  [[ -n "${reset_a}" ]] || fail "failed to format weekly reset time a"
  [[ -n "${reset_b}" ]] || fail "failed to format weekly reset time b"

  unset CODEX_STARSHIP_NAME_SOURCE CODEX_STARSHIP_SHOW_FULL_EMAIL_ENABLED

  typeset output='' expected=''
  output="$(codex-rate-limits --cached --one-line acc_a.json 2>/dev/null)"
  expected="acc_a 5h:54% W:63% ${reset_a}"
  assert_eq "${expected}" "${output}" "default should use secret filename" || fail "${output}"

  export CODEX_STARSHIP_NAME_SOURCE=email
  unset CODEX_STARSHIP_SHOW_FULL_EMAIL_ENABLED
  output="$(codex-rate-limits --cached --one-line acc_a.json 2>/dev/null)"
  expected="acc_a 5h:54% W:63% ${reset_a}"
  assert_eq "${expected}" "${output}" "rate-limits should ignore name_source=email" || fail "${output}"

  export CODEX_STARSHIP_SHOW_FULL_EMAIL_ENABLED=true
  output="$(codex-rate-limits --cached --one-line acc_a.json 2>/dev/null)"
  expected="acc_a 5h:54% W:63% ${reset_a}"
  assert_eq "${expected}" "${output}" "rate-limits should ignore show_full_email" || fail "${output}"

  output="$(codex-rate-limits-async --cached --jobs 2 2>/dev/null)"
  assert_contains "${output}" "acc_a" "async table should use secret filename for acc_a" || fail "${output}"
  assert_contains "${output}" "acc_b" "async table should use secret filename for acc_b" || fail "${output}"
  if [[ "${output}" == *"alice@example.com"* || "${output}" == *"bob@example.com"* ]]; then
    fail "async table should not include email addresses when printing names"
  fi

  print -r -- "OK"
}
