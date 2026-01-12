#!/usr/bin/env -S zsh -f

setopt pipe_fail nounset

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr TEST_DIR="${SCRIPT_PATH:h}"
typeset -gr REPO_ROOT="${TEST_DIR:h}"
typeset -gr BUNDLER_SCRIPT="$REPO_ROOT/tools/bundle-wrapper.zsh"
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

assert_contains_all() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset haystack="$1" context="$2"
  shift 2 || true

  typeset needle=''
  for needle in "$@"; do
    assert_contains "$haystack" "$needle" "$context (missing: $needle)"
  done
  return 0
}

typeset tmp_dir=''
tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t bundle-wrapper-test.XXXXXX)" || fail "mktemp failed"

{
  [[ -x "$BUNDLER_SCRIPT" ]] || fail "bundler not executable: $BUNDLER_SCRIPT"

  typeset out_dir="$tmp_dir/out"
  mkdir -p -- "$out_dir" || fail "mkdir failed: $out_dir"
  typeset out="$out_dir/open-changed-files"

  typeset manifest="$tmp_dir/wrapper.manifest.zsh"
  {
    print -r -- '#!/usr/bin/env -S zsh -f'
    print -r -- '# bundle-wrapper manifest (test)'
    print -r -- 'source "$ZSH_SCRIPT_DIR/_internal/wrappers.bundle-prelude.zsh"'
    print -r -- 'source "$ZSH_BOOTSTRAP_SCRIPT_DIR/00-preload.zsh"'
    print -r --
    print -r -- 'typeset -a exec_sources=('
    print -r -- '  "tools/open-changed-files.zsh"'
    print -r -- ')'
  } >| "$manifest"

  ZDOTDIR="$REPO_ROOT" "$ZSH_BIN" -f -- "$BUNDLER_SCRIPT" \
    --input "$manifest" \
    --output "$out" \
    --entry open-changed-files \
    >/dev/null || fail "bundler failed"

  [[ -x "$out" ]] || fail "output wrapper not executable: $out"

  typeset pwd_ws="$tmp_dir/pwd-workspace"
  mkdir -p -- "$pwd_ws" || fail "mkdir failed: $pwd_ws"

  typeset file1="$tmp_dir/file1.txt"
  typeset file2="$tmp_dir/dir/file2.txt"
  mkdir -p -- "${file2:h}" || fail "mkdir failed: ${file2:h}"
  print -r -- "one" >| "$file1"
  print -r -- "two" >| "$file2"

  typeset pwd_ws_abs="${pwd_ws:A}"
  typeset file1_abs="${file1:A}"
  typeset file2_abs="${file2:A}"

  typeset output='' rc=0 expected=''
  output="$(cd "$pwd_ws" && "$ZSH_BIN" -f -- "$out" --dry-run "$file1_abs" "$file2_abs" 2>&1)"
  rc=$?
  assert_eq 0 "$rc" "wrapper should exit 0" || fail "$output"
  assert_contains_all "$output" "wrapper dry-run output should include expected args" \
    "--new-window" \
    "-- $pwd_ws_abs $file1_abs $file2_abs" || fail "$output"

  print -r -- "OK"
} always {
  rm -rf -- "$tmp_dir"
}
