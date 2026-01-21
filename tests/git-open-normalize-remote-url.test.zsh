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

set_remote_and_assert() {
  emulate -L zsh
  setopt pipe_fail nounset

  typeset repo_dir="$1" url="$2" expected="$3" context="$4"
  git -C "$repo_dir" remote set-url origin "$url" || return 1

  typeset normalized=''
  normalized="$(
    cd "$repo_dir" && {
      source "$REPO_ROOT/scripts/git/git-open.zsh" || exit 1
      git-normalize-remote-url origin
    }
  )" || return 1

  assert_eq "$expected" "$normalized" "$context"
}

typeset tmp_dir=''
tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t git-open-normalize-test.XXXXXX)" || fail "mktemp failed"

{
  typeset repo_dir="$tmp_dir/repo"
  mkdir -p -- "$repo_dir" || fail "mkdir failed: $repo_dir"

  (cd "$repo_dir" && git init -b main -q) || fail "git init failed"
  (cd "$repo_dir" && git remote add origin https://example.invalid/seed.git) || fail "git remote add failed"

  set_remote_and_assert \
    "$repo_dir" \
    "git@github.com:org/repo.git" \
    "https://github.com/org/repo" \
    "scp-style github.com should normalize" || fail "scp-style failed"

  set_remote_and_assert \
    "$repo_dir" \
    "ssh://git@github.com/org/repo.git" \
    "https://github.com/org/repo" \
    "ssh url should normalize" || fail "ssh url failed"

  set_remote_and_assert \
    "$repo_dir" \
    "ssh://git@github.company:2222/org/repo.git" \
    "https://github.company:2222/org/repo" \
    "ssh url with port should preserve port" || fail "ssh url with port failed"

  set_remote_and_assert \
    "$repo_dir" \
    "https://git@github.com/org/repo.git" \
    "https://github.com/org/repo" \
    "https url with git@ should normalize" || fail "https git@ failed"

  set_remote_and_assert \
    "$repo_dir" \
    "git@github.com/org/repo.git" \
    "https://github.com/org/repo" \
    "git@host/path should normalize" || fail "git@host/path failed"

  set_remote_and_assert \
    "$repo_dir" \
    "git://github.com/org/repo.git" \
    "https://github.com/org/repo" \
    "git protocol should normalize" || fail "git:// failed"

  print -r -- "OK"
} always {
  rm -rf -- "$tmp_dir"
}
