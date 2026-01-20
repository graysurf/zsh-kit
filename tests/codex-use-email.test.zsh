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

write_secret() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset target="$1" token="$2"
  {
    print -r -- '{'
    print -r -- '  "tokens": {'
    print -r -- "    \"id_token\": \"${token}\""
    print -r -- '  }'
    print -r -- '}'
  } >| "${target}"
}

{
  typeset tmp_root=''
  tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/codex-use-email-test.XXXXXX" 2>/dev/null)" || tmp_root=''
  [[ -n "${tmp_root}" && -d "${tmp_root}" ]] || fail "failed to create temp dir"
  trap "command rm -rf -- ${(qq)tmp_root} 2>/dev/null || true" EXIT

  typeset cache_root="${tmp_root}/cache"
  typeset secret_dir="${tmp_root}/secrets"
  mkdir -p -- "${cache_root}" "${secret_dir}" || fail "failed to create temp directories"

  typeset payload_alice='eyJlbWFpbCI6ImFsaWNlQGV4YW1wbGUuY29tIiwic3ViIjoic3ViLTEyMyJ9'
  typeset payload_bob='eyJlbWFpbCI6ImJvYkBleGFtcGxlLmNvbSIsInN1YiI6InN1Yi00NTYifQ'
  typeset payload_same_a='eyJlbWFpbCI6InNhbWVAZXhhbXBsZS5jb20iLCJzdWIiOiJzdWItNzg5In0'
  typeset payload_same_b='eyJlbWFpbCI6InNhbWVAb3RoZXIuY29tIiwic3ViIjoic3ViLTc5MCJ9'

  typeset token_alice="a.${payload_alice}.b"
  typeset token_bob="a.${payload_bob}.b"
  typeset token_same_a="a.${payload_same_a}.b"
  typeset token_same_b="a.${payload_same_b}.b"

  write_secret "${secret_dir}/alpha.json" "${token_alice}" || fail "failed to write alpha.json"
  write_secret "${secret_dir}/bravo.json" "${token_bob}" || fail "failed to write bravo.json"
  write_secret "${secret_dir}/same1.json" "${token_same_a}" || fail "failed to write same1.json"
  write_secret "${secret_dir}/same2.json" "${token_same_b}" || fail "failed to write same2.json"

  typeset auth_file="${tmp_root}/auth.json"

  source "${REPO_ROOT}/bootstrap/00-preload.zsh"
  export CODEX_SECRET_DIR="${secret_dir}"
  export CODEX_AUTH_FILE="${auth_file}"
  export ZSH_CACHE_DIR="${cache_root}"
  source "${REPO_ROOT}/scripts/_features/codex/_codex-secret.zsh"

  rm -f -- "${auth_file}"

  typeset output='' email='' exit_code=0

  output="$(codex-use alpha 2>&1)" || fail "${output}"
  assert_contains "${output}" "codex: applied alpha.json" "switch by secret name should apply alpha.json" || fail "${output}"
  email="$(_codex_auth_email "${auth_file}" 2>/dev/null)" || email=''
  assert_eq "alice@example.com" "${email}" "auth file should contain alice email" || fail "${email}"

  output="$(codex-use bob 2>&1)" || fail "${output}"
  assert_contains "${output}" "codex: applied bravo.json" "switch by email local-part should resolve to bravo.json" || fail "${output}"
  email="$(_codex_auth_email "${auth_file}" 2>/dev/null)" || email=''
  assert_eq "bob@example.com" "${email}" "auth file should contain bob email" || fail "${email}"

  output="$(codex-use same@example.com 2>&1)" || fail "${output}"
  assert_contains "${output}" "codex: applied same1.json" "switch by full email should resolve to same1.json" || fail "${output}"
  email="$(_codex_auth_email "${auth_file}" 2>/dev/null)" || email=''
  assert_eq "same@example.com" "${email}" "auth file should contain same@example.com" || fail "${email}"

  exit_code=0
  output="$(codex-use same 2>&1)" || exit_code=$?
  assert_eq "2" "${exit_code}" "ambiguous local-part should return exit code 2" || fail "${output}"
  assert_contains "${output}" "identifier matches multiple secrets" "ambiguous local-part should report ambiguity" || fail "${output}"
  assert_contains "${output}" "same1.json" "ambiguous local-part should list same1.json" || fail "${output}"
  assert_contains "${output}" "same2.json" "ambiguous local-part should list same2.json" || fail "${output}"

  print -r -- "OK"
}
