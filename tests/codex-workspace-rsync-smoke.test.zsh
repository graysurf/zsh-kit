#!/usr/bin/env -S zsh -f

setopt pipe_fail nounset

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr TEST_DIR="${SCRIPT_PATH:h}"
typeset -gr REPO_ROOT="${TEST_DIR:h}"
typeset -gr RSYNC_SCRIPT="$REPO_ROOT/scripts/_features/codex-workspace/workspace-rsync.zsh"
typeset -gr LAUNCHER_SCRIPT="$REPO_ROOT/scripts/_features/codex-workspace/workspace-launcher.zsh"

fail() {
  emulate -L zsh
  setopt pipe_fail nounset

  print -u2 -r -- "FAIL: $*"
  exit 1
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
tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t codex-ws-rsync-test.XXXXXX)" || fail "mktemp failed"

{
  [[ -f "$RSYNC_SCRIPT" ]] || fail "missing rsync script: $RSYNC_SCRIPT"
  source "$RSYNC_SCRIPT"
  [[ -f "$LAUNCHER_SCRIPT" ]] || fail "missing launcher script: $LAUNCHER_SCRIPT"
  source "$LAUNCHER_SCRIPT"

  typeset stub_bin="$tmp_dir/bin"
  mkdir -p -- "$stub_bin" || fail "mkdir failed: $stub_bin"

  typeset docker_log="$tmp_dir/docker.log"
  : >| "$docker_log"

  typeset stub_docker="$stub_bin/docker"
  {
    print -r -- '#!/usr/bin/env -S zsh -f'
    print -r -- 'setopt nounset'
    print -r -- 'log="${CODEX_TEST_DOCKER_LOG:?missing CODEX_TEST_DOCKER_LOG}"'
    print -r -- 'print -r -- "docker $*" >>| "$log"'
    print -r -- 'if [[ "${1-}" == "exec" ]]; then'
    print -r -- '  # Always succeed for the container rsync --version check.'
    print -r -- '  exit 0'
    print -r -- 'fi'
    print -r -- 'exit 0'
  } >| "$stub_docker"
  chmod 700 "$stub_docker" || fail "chmod failed: $stub_docker"

  typeset rsync_log="$tmp_dir/rsync.log"
  : >| "$rsync_log"

  typeset wrapper_out="$tmp_dir/rsh-wrapper.sh"
  : >| "$wrapper_out"

  typeset stub_rsync="$stub_bin/rsync"
  {
    print -r -- '#!/usr/bin/env -S zsh -f'
    print -r -- 'setopt nounset'
    print -r -- 'log="${CODEX_TEST_RSYNC_LOG:?missing CODEX_TEST_RSYNC_LOG}"'
    print -r -- 'wrapper_out="${CODEX_TEST_RSYNC_WRAPPER_OUT:?missing CODEX_TEST_RSYNC_WRAPPER_OUT}"'
    print -r -- 'print -r -- "ENV container=${CODEX_WORKSPACE_RSYNC_CONTAINER-} user=${CODEX_WORKSPACE_RSYNC_USER-}" >>| "$log"'
    print -r -- 'typeset arg="" prev="" wrapper=""'
    print -r -- 'for arg in "$@"; do'
    print -r -- '  print -r -- "ARG=$arg" >>| "$log"'
    print -r -- '  if [[ "$prev" == "-e" ]]; then wrapper="$arg"; fi'
    print -r -- '  prev="$arg"'
    print -r -- 'done'
    print -r -- 'if [[ -n "$wrapper" ]]; then'
    print -r -- '  print -r -- "WRAPPER=$wrapper" >>| "$log"'
    print -r -- '  if [[ -f "$wrapper" ]]; then'
    print -r -- '    command cat "$wrapper" >| "$wrapper_out"'
    print -r -- '  else'
    print -r -- '    print -r -- "WRAPPER_MISSING=1" >>| "$log"'
    print -r -- '  fi'
    print -r -- 'fi'
    print -r -- 'exit 0'
  } >| "$stub_rsync"
  chmod 700 "$stub_rsync" || fail "chmod failed: $stub_rsync"

  typeset resolve_log="$tmp_dir/resolve.log"
  : >| "$resolve_log"

  _codex_workspace_resolve_container() {
    emulate -L zsh
    setopt pipe_fail

    print -r -- "${1-}" >>| "$resolve_log"
    print -r -- "codex-ws-test"
    return 0
  }

  _codex_workspace_ensure_container_running() { return 0 }

  # Push (explicit container arg).
  (
    export PATH="$stub_bin:$PATH"
    export CODEX_TEST_DOCKER_LOG="$docker_log"
    export CODEX_TEST_RSYNC_LOG="$rsync_log"
    export CODEX_TEST_RSYNC_WRAPPER_OUT="$wrapper_out"
    codex-workspace rsync push ws-arg ./src/ /work/src/ >/dev/null 2>&1
  ) || fail "rsync push should succeed"

  typeset resolved=''
  resolved="$(command cat "$resolve_log" 2>/dev/null || true)"
  assert_contains "$resolved" "ws-arg" "should pass container arg to resolver" || fail "$resolved"

  typeset rsync_meta=''
  rsync_meta="$(command cat "$rsync_log" 2>/dev/null || true)"
  assert_contains "$rsync_meta" "ENV container=codex-ws-test user=codex" "should set wrapper env vars" || fail "$rsync_meta"
  assert_contains "$rsync_meta" "ARG=-rlpt" "should use -rlpt defaults" || fail "$rsync_meta"
  assert_contains "$rsync_meta" "ARG=./src/" "should include src path" || fail "$rsync_meta"
  assert_contains "$rsync_meta" "ARG=codex-ws-test:/work/src/" "should include remote dest" || fail "$rsync_meta"

  typeset wrapper_path=''
  wrapper_path="${${(f)rsync_meta}[(r)WRAPPER=*]#WRAPPER=}"
  [[ -n "$wrapper_path" ]] || fail "missing WRAPPER=... in rsync log"
  [[ ! -e "$wrapper_path" ]] || fail "wrapper should be removed after rsync (got: $wrapper_path)"

  typeset wrapper_body=''
  wrapper_body="$(command cat "$wrapper_out" 2>/dev/null || true)"
  assert_contains "$wrapper_body" "docker exec -u" "wrapper should use docker exec" || fail "$wrapper_body"

  # Pull (container omitted; rsync args after paths should be inserted before paths).
  : >| "$rsync_log"
  : >| "$wrapper_out"

  (
    export PATH="$stub_bin:$PATH"
    export CODEX_TEST_DOCKER_LOG="$docker_log"
    export CODEX_TEST_RSYNC_LOG="$rsync_log"
    export CODEX_TEST_RSYNC_WRAPPER_OUT="$wrapper_out"
    codex-workspace rsync pull /work/repo/ ./repo/ --exclude '.git' >/dev/null 2>&1
  ) || fail "rsync pull should succeed"

  rsync_meta="$(command cat "$rsync_log" 2>/dev/null || true)"
  assert_contains "$rsync_meta" "ARG=--exclude" "should pass through rsync args" || fail "$rsync_meta"
  assert_contains "$rsync_meta" "ARG=.git" "should pass through rsync arg value" || fail "$rsync_meta"
  assert_contains "$rsync_meta" "ARG=codex-ws-test:/work/repo/" "should include remote src" || fail "$rsync_meta"
  assert_contains "$rsync_meta" "ARG=./repo/" "should include local dest" || fail "$rsync_meta"

  # Root mode should set container user.
  : >| "$rsync_log"

  (
    export PATH="$stub_bin:$PATH"
    export CODEX_TEST_DOCKER_LOG="$docker_log"
    export CODEX_TEST_RSYNC_LOG="$rsync_log"
    export CODEX_TEST_RSYNC_WRAPPER_OUT="$wrapper_out"
    codex-workspace rsync push --root ws-arg ./src/ /work/src/ >/dev/null 2>&1
  ) || fail "rsync push --root should succeed"

  rsync_meta="$(command cat "$rsync_log" 2>/dev/null || true)"
  assert_contains "$rsync_meta" "ENV container=codex-ws-test user=root" "should set wrapper user=root" || fail "$rsync_meta"
}

