#!/usr/bin/env -S zsh -f

setopt pipe_fail nounset

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr TEST_DIR="${SCRIPT_PATH:h}"
typeset -gr REPO_ROOT="${TEST_DIR:h}"
typeset -gr ZSH_BIN="$(command -v zsh)"

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
  [[ -n "$ZSH_BIN" && -x "$ZSH_BIN" ]] || fail "missing zsh binary"

  typeset tmp_root=''
  tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/codex-tools-rate-limits-async-test.XXXXXX" 2>/dev/null)" || tmp_root=''
  [[ -n "${tmp_root}" && -d "${tmp_root}" ]] || fail "failed to create temp dir"
  trap "command rm -rf -- ${(qq)tmp_root} 2>/dev/null || true" EXIT

  typeset module_dir="${tmp_root}/module"
  typeset cache_root="${tmp_root}/cache"
  typeset cache_dir="${cache_root}/codex/starship-rate-limits"

  mkdir -p -- "${module_dir}" "${cache_dir}" || fail "failed to create temp directories"

  typeset secret_script_src="${REPO_ROOT}/scripts/_features/codex/secrets/_codex-secret.zsh"
  typeset secret_script="${module_dir}/_codex-secret.zsh"
  cp -f -- "${secret_script_src}" "${secret_script}" || fail "failed to copy _codex-secret.zsh for isolated secrets dir"

  typeset fixed_now_epoch=1700000000
  typeset name='' weekly_epoch='' non_weekly_epoch='' cache_file='' secret_file=''
  for name weekly_epoch non_weekly_epoch in \
    acc_b $(( fixed_now_epoch + 84000 )) $(( fixed_now_epoch + 18000 )) \
    acc_c $(( fixed_now_epoch + 90000 )) $(( fixed_now_epoch + 17940 )) \
    acc_12345678901234567890 $(( fixed_now_epoch + 172800 )) $(( fixed_now_epoch + 18000 )); do
    secret_file="${module_dir}/${name}.json"
    print -r -- '{}' >| "${secret_file}" || fail "failed to write secret: ${secret_file}"

    cache_file="${cache_dir}/${name}.kv"
    {
      print -r -- 'fetched_at=1700000000'
      print -r -- 'non_weekly_label=1h'
      print -r -- 'non_weekly_remaining=90'
      print -r -- "non_weekly_reset_epoch=${non_weekly_epoch}"
      print -r -- 'weekly_remaining=80'
      print -r -- "weekly_reset_epoch=${weekly_epoch}"
    } >| "${cache_file}" || fail "failed to write cache: ${cache_file}"
  done

  typeset output='' rc=0
  output="$(
    cd "$REPO_ROOT" && \
      "$ZSH_BIN" -f -c '
        date() {
          if [[ "$#" -eq 1 && "$1" == "+%s" ]]; then
            print -r -- '"${fixed_now_epoch}"'
            return 0
          fi
          command date "$@"
        }
        source bootstrap/00-preload.zsh
        export CODEX_SECRET_DIR="'"${module_dir}"'"
        export ZSH_CACHE_DIR="'"${cache_root}"'"
        source "'"${secret_script}"'"
        source scripts/_features/codex/codex-tools.zsh
        codex-tools rate-limits --all --async --cached --jobs 2
      ' 2>&1
  )"
  rc=$?

  assert_eq 0 "$rc" "codex-tools rate-limits --async should exit 0" || fail "$output"
  assert_contains "$output" "Codex rate limits for all accounts" "should dispatch to async implementation" || fail "$output"

  print -r -- "OK"
}

