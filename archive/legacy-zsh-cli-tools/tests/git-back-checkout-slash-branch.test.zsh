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

typeset tmp_dir=''
tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t git-back-checkout-test.XXXXXX)" || fail "mktemp failed"

{
  typeset repo_dir="$tmp_dir/repo"
  mkdir -p -- "$repo_dir" || fail "mkdir failed: $repo_dir"

  (cd "$repo_dir" && git init -b main -q) || fail "git init failed"
  (cd "$repo_dir" && git config user.email test@example.com && git config user.name test) || fail "git config failed"

  print -r -- "a" >| "$repo_dir/a.txt"
  (cd "$repo_dir" && git add a.txt && git commit -qm init) || fail "git commit failed"

  (cd "$repo_dir" && git checkout -b 'feature/foo' -q) || fail "git checkout -b feature/foo failed"

  typeset branch=''
  branch="$(cd "$repo_dir" && git branch --show-current)" || fail "git branch --show-current failed"
  assert_eq "feature/foo" "$branch" "should start on feature/foo" || fail "branch=$branch"

  typeset output='' rc=0
  output="$(
    cd "$repo_dir" && {
      source "$REPO_ROOT/scripts/git/tools/git-reset.zsh" || exit 1
      git-back-checkout <<< $'y\n'
    } 2>&1
  )"
  rc=$?
  assert_eq 0 "$rc" "git-back-checkout should succeed when current branch contains '/'" || fail "$output"

  branch="$(cd "$repo_dir" && git branch --show-current)" || fail "git branch --show-current failed"
  assert_eq "main" "$branch" "git-back-checkout should return to main" || fail "branch=$branch"

  print -r -- "OK"
} always {
  rm -rf -- "$tmp_dir"
}

