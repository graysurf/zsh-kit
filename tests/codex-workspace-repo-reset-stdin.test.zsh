#!/usr/bin/env -S zsh -f

setopt pipe_fail nounset

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr TEST_DIR="${SCRIPT_PATH:h}"
typeset -gr REPO_ROOT="${TEST_DIR:h}"
typeset -gr FEATURE_SCRIPT="$REPO_ROOT/scripts/_features/codex-workspace/repo-reset.zsh"

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

assert_not_contains() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset haystack="$1" needle="$2" context="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    print -u2 -r -- "Unexpected substring: $needle"
    print -u2 -r -- "Context            : $context"
    return 1
  fi
  return 0
}

typeset tmp_dir=''
tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t codex-ws-repo-reset-stdin-test.XXXXXX)" || fail "mktemp failed"

{
  [[ -f "$FEATURE_SCRIPT" ]] || fail "missing feature script: $FEATURE_SCRIPT"
  source "$FEATURE_SCRIPT"

  _codex_workspace_require_docker() { return 0 }
  _codex_workspace_require_container() { return 0 }
  _codex_workspace_container_list_git_repos() {
    print -r -- "/work/a/repo"
    print -r -- "/work/b/repo"
  }

  typeset stub_bin="$tmp_dir/bin"
  mkdir -p -- "$stub_bin" || fail "mkdir failed: $stub_bin"

  typeset docker_log="$tmp_dir/docker.log"
  : >| "$docker_log"

  typeset stdin_log="$tmp_dir/docker.stdin"
  : >| "$stdin_log"

  typeset stub_docker="$stub_bin/docker"
  {
    print -r -- '#!/usr/bin/env -S zsh -f'
    print -r -- 'setopt nounset'
    print -r -- 'log="${CODEX_TEST_DOCKER_LOG:?missing CODEX_TEST_DOCKER_LOG}"'
    print -r -- 'stdin_log="${CODEX_TEST_DOCKER_STDIN_LOG:?missing CODEX_TEST_DOCKER_STDIN_LOG}"'
    print -r -- 'typeset -i has_c=0 has_s=0'
    print -r -- 'typeset arg=""'
    print -r -- 'for arg in "$@"; do'
    print -r -- '  [[ "$arg" == "-c" ]] && has_c=1'
    print -r -- '  [[ "$arg" == "-s" ]] && has_s=1'
    print -r -- 'done'
    print -r -- 'print -r -- "has_c=$has_c has_s=$has_s argv_count=$#" >>| "$log"'
    print -r -- 'if [[ "${1-}" == "exec" ]]; then'
    print -r -- '  command cat >| "$stdin_log" || true'
    print -r -- '  exit 0'
    print -r -- 'fi'
    print -r -- 'exit 0'
  } >| "$stub_docker"
  chmod 700 "$stub_docker" || fail "chmod failed: $stub_docker"

  typeset out='' rc=0
  out="$( \
    PATH="$stub_bin:$PATH" \
    CODEX_TEST_DOCKER_LOG="$docker_log" \
    CODEX_TEST_DOCKER_STDIN_LOG="$stdin_log" \
    codex-workspace-reset-work-repos test-container --yes --ref origin/main 2>&1 \
  )"
  rc=$?
  assert_eq 0 "$rc" "reset-work-repos should succeed with stub docker" || fail "$out"

  typeset docker_meta=''
  docker_meta="$(command cat "$docker_log" 2>/dev/null || true)"
  assert_contains "$docker_meta" "has_c=1" "docker exec should use zsh -c" || fail "$docker_meta"
  assert_contains "$docker_meta" "has_s=0" "docker exec should not use zsh -s" || fail "$docker_meta"

  typeset stdin_payload=''
  stdin_payload="$(command cat "$stdin_log" 2>/dev/null || true)"
  assert_contains "$stdin_payload" "/work/a/repo" "stdin should contain repo list" || fail "$stdin_payload"
  assert_contains "$stdin_payload" "/work/b/repo" "stdin should contain repo list" || fail "$stdin_payload"
  assert_not_contains "$stdin_payload" "set -euo pipefail" "stdin should not contain script" || fail "$stdin_payload"
}

