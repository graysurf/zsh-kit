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
tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t git-lock-tag-test.XXXXXX)" || fail "mktemp failed"

{
  typeset repo_dir="$tmp_dir/repo"
  mkdir -p -- "$repo_dir" || fail "mkdir failed: $repo_dir"

  (cd "$repo_dir" && git init -b main -q) || fail "git init failed"
  (cd "$repo_dir" && git config user.email test@example.com && git config user.name test) || fail "git config failed"

  print -r -- "a" >| "$repo_dir/a.txt"
  (cd "$repo_dir" && git add a.txt && git commit -qm init) || fail "git commit failed"

  typeset head_hash=''
  head_hash="$(cd "$repo_dir" && git rev-parse HEAD)" || fail "git rev-parse HEAD failed"

  export ZSH_CACHE_DIR="$tmp_dir/cache"
  mkdir -p -- "$ZSH_CACHE_DIR" || fail "mkdir failed: $ZSH_CACHE_DIR"

  typeset output='' rc=0
  output="$(
    cd "$repo_dir" && {
      source "$REPO_ROOT/scripts/git/git-lock.zsh" || exit 1
      git-lock lock snap "note"
      git-lock tag snap v0.0.0-test
    } 2>&1
  )"
  rc=$?
  assert_eq 0 "$rc" "git-lock tag should succeed with <label> <tag-name>" || fail "$output"

  typeset -a tags=()
  tags=("${(@f)$(cd "$repo_dir" && git tag --list)}")
  assert_eq 1 "${#tags[@]}" "should create exactly one tag" || fail "tags: ${(j:,:)tags}"
  assert_eq "v0.0.0-test" "${tags[1]}" "tag name should come from second arg" || fail "tags: ${(j:,:)tags}"

  typeset tag_hash=''
  tag_hash="$(cd "$repo_dir" && git rev-parse 'v0.0.0-test^{commit}')" || fail "git rev-parse tag failed"
  assert_eq "$head_hash" "$tag_hash" "tag should point at locked commit" || fail "head=$head_hash tag=$tag_hash"

  print -r -- "OK"
} always {
  rm -rf -- "$tmp_dir"
}

