#!/usr/bin/env -S zsh -f

setopt pipe_fail nounset

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr TEST_DIR="${SCRIPT_PATH:h}"
typeset -gr REPO_ROOT="${TEST_DIR:h}"
typeset -gr FEATURE_DIR="$REPO_ROOT/scripts/_features/codex-workspace"

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

typeset tmp_dir=''
tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t codex-ws-auth-smoke-test.XXXXXX)" || fail "mktemp failed"

{
  [[ -f "$FEATURE_DIR/repo-reset.zsh" ]] || fail "missing repo-reset: $FEATURE_DIR/repo-reset.zsh"
  [[ -f "$FEATURE_DIR/workspace-rm.zsh" ]] || fail "missing workspace-rm: $FEATURE_DIR/workspace-rm.zsh"
  [[ -f "$FEATURE_DIR/workspace-launcher.zsh" ]] || fail "missing workspace-launcher: $FEATURE_DIR/workspace-launcher.zsh"
  source "$FEATURE_DIR/repo-reset.zsh"
  source "$FEATURE_DIR/workspace-rm.zsh"
  source "$FEATURE_DIR/workspace-launcher.zsh"

  typeset codex_log="$tmp_dir/codex-use.log"
  : >| "$codex_log"
  codex-use() {
    emulate -L zsh
    setopt pipe_fail
    print -r -- "codex-use $*" >>| "$codex_log"
    return 0
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
    print -r -- 'print -r -- "docker $*" >>| "$log"'
    print -r -- 'case "${1-}" in'
    print -r -- '  info)'
    print -r -- '    exit 0'
    print -r -- '    ;;'
    print -r -- '  inspect)'
    print -r -- '    if [[ "${2-}" == "-f" ]]; then'
    print -r -- '      print -r -- "true"'
    print -r -- '    fi'
    print -r -- '    exit 0'
    print -r -- '    ;;'
    print -r -- '  exec)'
    print -r -- '    if [[ " $* " == *" -i "* ]]; then'
    print -r -- '      command cat >| "$stdin_log" || true'
    print -r -- '    fi'
    print -r -- '    exit 0'
    print -r -- '    ;;'
    print -r -- '  start)'
    print -r -- '    exit 0'
    print -r -- '    ;;'
    print -r -- 'esac'
    print -r -- 'exit 0'
  } >| "$stub_docker"
  chmod 700 "$stub_docker" || fail "chmod failed: $stub_docker"

  typeset stub_gh="$stub_bin/gh"
  {
    print -r -- '#!/usr/bin/env -S zsh -f'
    print -r -- 'setopt nounset'
    print -r -- 'if [[ "${1-}" == "auth" && "${2-}" == "token" ]]; then'
    print -r -- '  print -r -- "${CODEX_TEST_GH_TOKEN:-}"'
    print -r -- '  exit 0'
    print -r -- 'fi'
    print -r -- 'exit 0'
  } >| "$stub_gh"
  chmod 700 "$stub_gh" || fail "chmod failed: $stub_gh"

  typeset output='' rc=0
  output="$( \
    PATH="$stub_bin:$PATH" \
    CODEX_TEST_DOCKER_LOG="$docker_log" \
    CODEX_TEST_DOCKER_STDIN_LOG="$stdin_log" \
    CODEX_TEST_GH_TOKEN="gh-test-token" \
    CODEX_WORKSPACE_AUTH=gh \
    codex-workspace auth github ws-test 2>&1 \
  )"
  rc=$?
  assert_eq 0 "$rc" "auth github should exit 0" || fail "$output"
  assert_contains "$output" "auth: github -> codex-ws-ws-test" "auth github should report container" || fail "$output"
  assert_contains "$output" "source=gh" "auth github should report gh source" || fail "$output"

  typeset docker_meta=''
  docker_meta="$(command cat "$docker_log" 2>/dev/null || true)"
  assert_contains "$docker_meta" "exec -i -u codex codex-ws-ws-test bash -lc" "auth github should exec into container" || fail "$docker_meta"

  typeset stdin_payload=''
  stdin_payload="$(command cat "$stdin_log" 2>/dev/null || true)"
  assert_contains "$stdin_payload" "gh-test-token" "auth github should pass token via stdin" || fail "$stdin_payload"

  : >| "$docker_log"
  : >| "$stdin_log"

  output="$( \
    PATH="$stub_bin:$PATH" \
    CODEX_TEST_DOCKER_LOG="$docker_log" \
    CODEX_TEST_DOCKER_STDIN_LOG="$stdin_log" \
    codex-workspace auth codex --profile work ws-test 2>&1 \
  )"
  rc=$?
  assert_eq 0 "$rc" "auth codex should exit 0" || fail "$output"
  assert_contains "$output" "auth: codex -> codex-ws-ws-test (profile=work)" "auth codex should report profile" || fail "$output"

  docker_meta="$(command cat "$docker_log" 2>/dev/null || true)"
  assert_contains "$docker_meta" "exec -u codex codex-ws-ws-test zsh -lc" "auth codex should exec into container" || fail "$docker_meta"

  typeset codex_meta=''
  codex_meta="$(command cat "$codex_log" 2>/dev/null || true)"
  assert_contains "$codex_meta" "codex-use work" "auth codex should update host profile" || fail "$codex_meta"

  print -r -- "OK"
} always {
  rm -rf -- "$tmp_dir"
}
