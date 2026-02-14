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
tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t git-lock-list-test.XXXXXX)" || fail "mktemp failed"

{
  typeset repo_dir="$tmp_dir/repo"
  mkdir -p -- "$repo_dir" || fail "mkdir failed: $repo_dir"

  (cd "$repo_dir" && git init -b main -q) || fail "git init failed"
  (cd "$repo_dir" && git config user.email test@example.com && git config user.name test) || fail "git config failed"

  print -r -- "a" >| "$repo_dir/a.txt"
  (cd "$repo_dir" && git add a.txt && git commit -qm init) || fail "git commit failed"

  export ZSH_CACHE_DIR="$tmp_dir/cache"
  mkdir -p -- "$ZSH_CACHE_DIR" || fail "mkdir failed: $ZSH_CACHE_DIR"

  source "$REPO_ROOT/bootstrap/define-loaders.zsh" || fail "failed to source bootstrap/define-loaders.zsh"

  cd "$repo_dir" || fail "cd failed: $repo_dir"
  source_file "$REPO_ROOT/scripts/git/git-lock.zsh" || fail "failed to source git-lock via source_file"

  assert_eq '^timestamp=' "${GIT_LOCK_TIMESTAMP_PATTERN-}" "GIT_LOCK_TIMESTAMP_PATTERN should persist after source_file" || fail

  git-lock lock snap "note" >/dev/null || fail "git-lock lock failed"

  typeset output='' rc=0
  output="$(git-lock list 2>&1)"
  rc=$?
  assert_eq 0 "$rc" "git-lock list should succeed" || fail "$output"

  if print -r -- "$output" | grep -qiE '(^date:|illegal option|usage: date)'; then
    fail "unexpected date stderr in git-lock list: $output"
  fi

  typeset time_line=''
  time_line="$(print -r -- "$output" | grep -m 1 '📅 time:' 2>/dev/null || true)"
  [[ -n "$time_line" ]] || fail "missing time line in git-lock list output: $output"

  if ! print -r -- "$time_line" | grep -Eq '📅 time:[[:space:]]+[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$'; then
    fail "unexpected time line format: $time_line"
  fi

  if [[ "$time_line" == *'#'* ]]; then
    fail "time line should not include hash/note: $time_line"
  fi

  print -r -- "OK"
} always {
  rm -rf -- "$tmp_dir"
}

