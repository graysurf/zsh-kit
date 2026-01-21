#!/usr/bin/env -S zsh -f

setopt pipe_fail nounset

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr TEST_DIR="${SCRIPT_PATH:h}"
typeset -gr REPO_ROOT="${TEST_DIR:h}"
typeset -gr FEATURE_SCRIPT="$REPO_ROOT/scripts/_features/codex-workspace/workspace-launcher.zsh"

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
tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t codex-workspace-launcher-test.XXXXXX)" || fail "mktemp failed"

{
  [[ -f "$FEATURE_SCRIPT" ]] || fail "missing feature script: $FEATURE_SCRIPT"
  source "$FEATURE_SCRIPT"

  typeset -gx CODEX_WORKSPACE_OPEN_VSCODE_ENABLED=false

  # Keep this test hermetic: avoid calling the real docker-dependent implementation.
  codex-workspace-refresh-opt-repos() {
    emulate -L zsh
    setopt pipe_fail

    return 0
  }

  typeset blob_url="https://github.com/graysurf/codex-kit/blob/main/docker/codex-env/bin/codex-workspace"
  typeset normalized=''
  normalized="$(_codex_workspace_launcher_normalize_url "$blob_url")" || fail "normalize_url failed"
  assert_eq "https://raw.githubusercontent.com/graysurf/codex-kit/main/docker/codex-env/bin/codex-workspace" "$normalized" "blob URL should normalize to raw" || fail "$normalized"

  typeset stub_bin="$tmp_dir/bin"
  mkdir -p -- "$stub_bin" || fail "mkdir failed: $stub_bin"

  typeset curl_log="$tmp_dir/curl.log"
  : >| "$curl_log"
  typeset stub_curl="$stub_bin/curl"
  {
    print -r -- '#!/usr/bin/env -S zsh -f'
    print -r -- 'setopt nounset'
    print -r -- 'log="${CODEX_TEST_CURL_LOG:?missing CODEX_TEST_CURL_LOG}"'
    print -r -- 'print -r -- "curl $*" >>| "$log"'
    print -r -- "cat <<'EOF'"
    print -r -- '#!/bin/sh'
    print -r -- 'set -eu'
    print -r -- 'log="${CODEX_TEST_LAUNCHER_LOG:-}"'
    print -r -- 'if [ -n "$log" ]; then printf "%s\n" "$*" >>"$log"; fi'
    print -r --
    print -r -- 'case "${1-}" in'
    print -r -- '  -h|--help|help|"")'
    print -r -- '    printf "%s\n" "--no-clone"'
    print -r -- '    exit 0'
    print -r -- '    ;;'
    print -r -- 'esac'
    print -r --
    print -r -- 'if [ "${1-}" = up ]; then'
    print -r -- '  printf "%s\n" "workspace:  codex-ws-test"'
    print -r -- '  printf "%s\n" "path:       /work"'
    print -r -- '  exit 0'
    print -r -- 'fi'
    print -r --
    print -r -- 'exit 0'
    print -r -- 'EOF'
  } >| "$stub_curl"
  chmod 700 "$stub_curl" || fail "chmod failed: $stub_curl"

  typeset docker_log="$tmp_dir/docker.log"
  : >| "$docker_log"
  typeset stub_docker="$stub_bin/docker"
  {
    print -r -- '#!/usr/bin/env -S zsh -f'
    print -r -- 'setopt nounset'
    print -r -- 'log="${CODEX_TEST_DOCKER_LOG:-}"'
    print -r -- 'if [[ -n "$log" ]]; then'
    print -r -- '  print -r -- "docker $*" >>| "$log"'
    print -r -- 'fi'
    print -r -- 'case "${1-}" in'
    print -r -- '  info)'
    print -r -- '    exit 0'
    print -r -- '    ;;'
    print -r -- '  context)'
    print -r -- '    if [[ "${2-}" == "show" ]]; then'
    print -r -- '      print -r -- "default"'
    print -r -- '    fi'
    print -r -- '    exit 0'
    print -r -- '    ;;'
    print -r -- '  exec)'
    print -r -- '    # Skip snapshot tar by claiming the marker exists.'
    print -r -- '    if [[ "$*" == *".codex-env/config.snapshot.ok"* ]]; then'
    print -r -- '      exit 0'
    print -r -- '    fi'
    print -r -- '    # Drain stdin in interactive mode to avoid blocking if a pipe is used.'
    print -r -- '    if [[ " $* " == *" -i "* ]]; then'
    print -r -- '      command cat >/dev/null 2>&1 || true'
    print -r -- '    fi'
    print -r -- '    exit 0'
    print -r -- '    ;;'
    print -r -- '  *)'
    print -r -- '    exit 0'
    print -r -- '    ;;'
    print -r -- 'esac'
  } >| "$stub_docker"
  chmod 700 "$stub_docker" || fail "chmod failed: $stub_docker"

  typeset stub_gh="$stub_bin/gh"
  {
    print -r -- '#!/usr/bin/env -S zsh -f'
    print -r -- 'exit 0'
  } >| "$stub_gh"
  chmod 700 "$stub_gh" || fail "chmod failed: $stub_gh"

  typeset auto_path="$tmp_dir/launcher/codex-workspace"
  typeset out='' rc=0 output=''

  out="$( \
    PATH="$stub_bin:$PATH" \
    CODEX_TEST_CURL_LOG="$curl_log" \
    CODEX_WORKSPACE_LAUNCHER_AUTO_PATH="$auto_path" \
    CODEX_WORKSPACE_LAUNCHER_URL="https://example.invalid/codex-workspace" \
    _codex_workspace_ensure_launcher "$tmp_dir/missing-launcher" 0 \
  )"
  rc=$?
  assert_eq 0 "$rc" "ensure_launcher should succeed via stub curl" || fail "$out"
  assert_eq "$auto_path" "$out" "ensure_launcher should return auto path" || fail "$out"
  [[ -x "$auto_path" ]] || fail "installed launcher should be executable: $auto_path"

  typeset -i curl_calls=0
  curl_calls="$(command wc -l < "$curl_log" | tr -d ' ')" || fail "wc failed"
  assert_eq 1 "$curl_calls" "ensure_launcher should call curl once" || fail "calls=$curl_calls"

  out="$( \
    PATH="$stub_bin:$PATH" \
    CODEX_TEST_CURL_LOG="$curl_log" \
    CODEX_WORKSPACE_LAUNCHER_AUTO_PATH="$auto_path" \
    CODEX_WORKSPACE_LAUNCHER_URL="https://example.invalid/codex-workspace" \
    _codex_workspace_ensure_launcher "$tmp_dir/missing-launcher" 0 \
  )"
  rc=$?
  assert_eq 0 "$rc" "ensure_launcher should be idempotent" || fail "$out"
  assert_eq "$auto_path" "$out" "second ensure_launcher should reuse auto path" || fail "$out"

  curl_calls="$(command wc -l < "$curl_log" | tr -d ' ')" || fail "wc failed"
  assert_eq 1 "$curl_calls" "second ensure_launcher should not re-download" || fail "calls=$curl_calls"

  rm -f -- "$auto_path" 2>/dev/null || true
  output="$( \
    PATH="$stub_bin:$PATH" \
    CODEX_TEST_CURL_LOG="$curl_log" \
    CODEX_WORKSPACE_LAUNCHER_AUTO_PATH="$auto_path" \
    CODEX_WORKSPACE_LAUNCHER_URL="https://example.invalid/codex-workspace" \
    CODEX_WORKSPACE_LAUNCHER_AUTO_DOWNLOAD=false \
    _codex_workspace_ensure_launcher "$tmp_dir/missing-launcher" 0 2>&1 \
  )"
  rc=$?
  [[ $rc -ne 0 ]] || fail "ensure_launcher should fail when auto-download disabled"
  assert_contains "$output" "auto-download disabled" "should explain auto-download disabled" || fail "$output"

  typeset output='' ok_rc=0
  output="$(codex-workspace create --no-work-repos 2>&1)"
  ok_rc=$?
  assert_eq 2 "$ok_rc" "--no-work-repos without --name should exit 2" || fail "$output"
  assert_contains "$output" "requires --name" "--no-work-repos should require --name" || fail "$output"

  output="$(codex-workspace create --no-work-repos --name ws foo/bar 2>&1)"
  ok_rc=$?
  assert_eq 2 "$ok_rc" "--no-work-repos with repo args should exit 2" || fail "$output"
  assert_contains "$output" "does not accept repo args" "--no-work-repos should reject repo args" || fail "$output"

  typeset launcher_no_clone="$tmp_dir/launcher-no-clone"
  {
    print -r -- '#!/bin/sh'
    print -r -- 'printf "%s\\n" "usage: codex-workspace up <repo> [--name <name>] ..."'
    print -r -- 'exit 0'
  } >| "$launcher_no_clone"
  chmod 700 "$launcher_no_clone" || fail "chmod failed: $launcher_no_clone"

  (
    export PATH="$stub_bin:$PATH"
    export CODEX_WORKSPACE_LAUNCHER="$launcher_no_clone"
    output="$(codex-workspace create --no-work-repos --name ws 2>&1)" && exit 0
    ok_rc=$?
    print -r -- "$ok_rc"
    print -r -- "$output"
  ) | {
    IFS=$'\n' read -r ok_rc || ok_rc=0
    IFS=$'\n' read -r output || output=''
    assert_eq 1 "$ok_rc" "launcher without --no-clone should be rejected" || fail "$output"
    assert_contains "$output" "does not support --no-clone" "should reject old launcher" || fail "$output"
  }

  typeset launcher_with_no_clone="$tmp_dir/launcher-with-no-clone"
  {
    print -r -- '#!/bin/sh'
    print -r -- 'printf "%s\\n" "--no-clone"'
    print -r -- 'exit 0'
  } >| "$launcher_with_no_clone"
  chmod 700 "$launcher_with_no_clone" || fail "chmod failed: $launcher_with_no_clone"

  typeset launcher_args_log="$tmp_dir/launcher.args.log"
  : >| "$launcher_args_log"

  typeset fake_home="$tmp_dir/fake-home"
  mkdir -p -- "$fake_home" || fail "mkdir failed: $fake_home"

	  output="$( \
	    PATH="$stub_bin:$PATH" \
	    HOME="$fake_home" \
	    XDG_CACHE_HOME="$tmp_dir/xdg-cache" \
	    CODEX_TEST_CURL_LOG="$curl_log" \
	    CODEX_TEST_DOCKER_LOG="$docker_log" \
	    CODEX_TEST_LAUNCHER_LOG="$launcher_args_log" \
	    CODEX_WORKSPACE_LAUNCHER_AUTO_PATH="$tmp_dir/xdg-cache/codex-workspace/launcher/codex-workspace" \
	    CODEX_WORKSPACE_LAUNCHER_URL="https://example.invalid/codex-workspace" \
	    CODEX_WORKSPACE_AUTH=none \
	    CODEX_WORKSPACE_GPG=none \
	    CODEX_WORKSPACE_PRIVATE_REPO="" \
	    codex-workspace create --no-work-repos --name ws 2>&1 \
	  )"
  ok_rc=$?
  assert_eq 0 "$ok_rc" "create --no-work-repos should succeed with docker+curl stubs" || fail "$output"
  assert_contains "$output" "workspace:" "create should surface launcher output" || fail "$output"
  assert_contains "$output" "snapshot: ~/.config already copied" "create should skip snapshot tar when marker exists" || fail "$output"
  assert_contains "$output" "Dev Containers:" "create should print Dev Containers hints" || fail "$output"
  assert_contains "$output" "  - Open:   /work" "create should print an Open path for Dev Containers" || fail "$output"
  assert_contains "$output" 'code --new-window --folder-uri "vscode-remote://attached-container+' "create should print a VS Code folder-uri command" || fail "$output"
  assert_contains "$output" "  - Link:   vscode://vscode-remote/attached-container+" "create should print a clickable vscode:// link" || fail "$output"

  typeset launcher_args=''
  launcher_args="$(command cat -- "$launcher_args_log" 2>/dev/null || true)"
  assert_contains "$launcher_args" "--help" "create should probe launcher --help" || fail "$launcher_args"
  assert_contains "$launcher_args" "up --no-clone" "create should call launcher up --no-clone" || fail "$launcher_args"
  assert_contains "$launcher_args" "--name ws" "create should pass --name" || fail "$launcher_args"
  assert_contains "$launcher_args" "--host github.com" "create should pass --host" || fail "$launcher_args"
  assert_contains "$launcher_args" "--secrets-dir" "create should pass secrets args" || fail "$launcher_args"
  assert_not_contains "$launcher_args" "foo/bar" "create --no-work-repos should not pass repo args" || fail "$launcher_args"

  print -r -- "OK"
} always {
  rm -rf -- "$tmp_dir"
}
