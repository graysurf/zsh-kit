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
tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t codex-ws-create-gpg-smoke-test.XXXXXX)" || fail "mktemp failed"

{
  [[ -f "$FEATURE_DIR/repo-reset.zsh" ]] || fail "missing repo-reset: $FEATURE_DIR/repo-reset.zsh"
  [[ -f "$FEATURE_DIR/workspace-rm.zsh" ]] || fail "missing workspace-rm: $FEATURE_DIR/workspace-rm.zsh"
  [[ -f "$FEATURE_DIR/workspace-launcher.zsh" ]] || fail "missing workspace-launcher: $FEATURE_DIR/workspace-launcher.zsh"
  source "$FEATURE_DIR/repo-reset.zsh"
  source "$FEATURE_DIR/workspace-rm.zsh"
  source "$FEATURE_DIR/workspace-launcher.zsh"

  # Keep the test hermetic: avoid docker-dependent refresh behavior.
  codex-workspace-refresh-opt-repos() {
    emulate -L zsh
    setopt pipe_fail

    return 0
  }

  typeset stub_bin="$tmp_dir/bin"
  mkdir -p -- "$stub_bin" || fail "mkdir failed: $stub_bin"

  typeset docker_log="$tmp_dir/docker.log"
  : >| "$docker_log"
  typeset stdin_log="$tmp_dir/docker.stdin"
  : >| "$stdin_log"
  typeset gpg_log="$tmp_dir/gpg.log"
  : >| "$gpg_log"
  typeset launcher_log="$tmp_dir/launcher.args.log"
  : >| "$launcher_log"

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
    print -r -- '  start)'
    print -r -- '    exit 0'
    print -r -- '    ;;'
    print -r -- '  exec)'
    print -r -- '    # Skip snapshot tar by claiming the marker exists.'
    print -r -- '    if [[ "$*" == *".codex-env/config.snapshot.ok"* ]]; then'
    print -r -- '      exit 0'
    print -r -- '    fi'
    print -r -- '    if [[ " $* " == *" -i "* ]]; then'
    print -r -- '      command cat >| "$stdin_log" || true'
    print -r -- '    fi'
    print -r -- '    exit 0'
    print -r -- '    ;;'
    print -r -- 'esac'
    print -r -- 'exit 0'
  } >| "$stub_docker"
  chmod 700 "$stub_docker" || fail "chmod failed: $stub_docker"

  typeset stub_gh="$stub_bin/gh"
  {
    print -r -- '#!/usr/bin/env -S zsh -f'
    print -r -- 'exit 0'
  } >| "$stub_gh"
  chmod 700 "$stub_gh" || fail "chmod failed: $stub_gh"

  typeset stub_gpg="$stub_bin/gpg"
  {
    print -r -- '#!/usr/bin/env -S zsh -f'
    print -r -- 'setopt nounset'
    print -r -- 'log="${CODEX_TEST_GPG_LOG:?missing CODEX_TEST_GPG_LOG}"'
    print -r -- 'print -r -- "gpg $*" >>| "$log"'
    print -r -- 'if [[ " $* " == *" --export-secret-keys "* ]]; then'
    print -r -- '  key="${argv[-1]-}"'
    print -r -- '  print -r -- "FAKE-SECRET-KEY:${key}"'
    print -r -- '  exit 0'
    print -r -- 'fi'
    print -r -- 'exit 0'
  } >| "$stub_gpg"
  chmod 700 "$stub_gpg" || fail "chmod failed: $stub_gpg"

  typeset stub_launcher="$tmp_dir/launcher"
  {
    print -r -- '#!/bin/sh'
    print -r -- 'set -eu'
    print -r -- 'log="${CODEX_TEST_LAUNCHER_LOG:-}"'
    print -r -- 'if [ -n "$log" ]; then printf "%s\n" "$*" >>"$log"; fi'
    print -r -- 'case "${1-}" in'
    print -r -- '  -h|--help|help|"")'
    print -r -- '    printf "%s\n" "--no-clone"'
    print -r -- '    exit 0'
    print -r -- '    ;;'
    print -r -- 'esac'
    print -r -- 'if [ "${1-}" = up ]; then'
    print -r -- '  printf "%s\n" "workspace:  codex-ws-ws-test"'
    print -r -- '  printf "%s\n" "path:       /work"'
    print -r -- '  exit 0'
    print -r -- 'fi'
    print -r -- 'exit 0'
  } >| "$stub_launcher"
  chmod 700 "$stub_launcher" || fail "chmod failed: $stub_launcher"

  typeset output='' rc=0

  output="$( \
    PATH="$stub_bin:$PATH" \
    CODEX_WORKSPACE_LAUNCHER="$stub_launcher" \
    CODEX_WORKSPACE_AUTH=none \
    CODEX_TEST_DOCKER_LOG="$docker_log" \
    CODEX_TEST_DOCKER_STDIN_LOG="$stdin_log" \
    CODEX_TEST_GPG_LOG="$gpg_log" \
    CODEX_TEST_LAUNCHER_LOG="$launcher_log" \
    codex-workspace create --no-work-repos --name ws-test --gpg --gpg-key KEY123 2>&1 \
  )"
  rc=$?
  assert_eq 0 "$rc" "create --gpg should exit 0" || fail "$output"
  assert_contains "$output" "workspace:" "create should surface launcher output" || fail "$output"
  assert_contains "$output" "auth: gpg -> codex-ws-ws-test" "create --gpg should trigger gpg auth" || fail "$output"

  typeset gpg_meta=''
  gpg_meta="$(command cat "$gpg_log" 2>/dev/null || true)"
  assert_contains "$gpg_meta" "--export-secret-keys" "create --gpg should export secret key on host" || fail "$gpg_meta"
  assert_contains "$gpg_meta" "KEY123" "create --gpg should export the requested key" || fail "$gpg_meta"

  typeset stdin_payload=''
  stdin_payload="$(command cat "$stdin_log" 2>/dev/null || true)"
  assert_contains "$stdin_payload" "FAKE-SECRET-KEY:KEY123" "create --gpg should stream key material via stdin" || fail "$stdin_payload"

  : >| "$gpg_log"
  : >| "$stdin_log"

  output="$( \
    PATH="$stub_bin:$PATH" \
    CODEX_WORKSPACE_LAUNCHER="$stub_launcher" \
    CODEX_WORKSPACE_AUTH=none \
    CODEX_WORKSPACE_GPG=import \
    CODEX_TEST_DOCKER_LOG="$docker_log" \
    CODEX_TEST_DOCKER_STDIN_LOG="$stdin_log" \
    CODEX_TEST_GPG_LOG="$gpg_log" \
    CODEX_TEST_LAUNCHER_LOG="$launcher_log" \
    codex-workspace create --no-work-repos --name ws-test --no-gpg 2>&1 \
  )"
  rc=$?
  assert_eq 0 "$rc" "create --no-gpg should exit 0" || fail "$output"

  gpg_meta="$(command cat "$gpg_log" 2>/dev/null || true)"
  assert_eq "" "$gpg_meta" "create --no-gpg should skip host gpg calls" || fail "$gpg_meta"

  stdin_payload="$(command cat "$stdin_log" 2>/dev/null || true)"
  assert_eq "" "$stdin_payload" "create --no-gpg should not stream gpg material" || fail "$stdin_payload"

  print -r -- "OK"
} always {
  rm -rf -- "$tmp_dir"
}

