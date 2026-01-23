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

assert_contains() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset haystack="$1" needle="$2" context="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    print -u2 -r -- "Missing: $needle"
    print -u2 -r -- "Context: $context"
    return 1
  fi
  return 0
}

assert_not_contains() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset haystack="$1" needle="$2" context="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    print -u2 -r -- "Unexpected: $needle"
    print -u2 -r -- "Context: $context"
    return 1
  fi
  return 0
}

typeset tmp_dir=''
tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t git-scope-print-sources-test.XXXXXX)" || fail "mktemp failed"
trap 'rm -rf "$tmp_dir"' EXIT

{
  cd "$tmp_dir" || exit 1

  git init -q || exit 1
  git config user.email "test@example.com" || exit 1
  git config user.name "Test User" || exit 1
  git config commit.gpgsign false >/dev/null 2>&1 || true

  print -r -- "BASE" > only_staged.txt
  print -r -- "BASE" > only_unstaged.txt
  print -r -- "BASE" > both.txt

  git add . || exit 1
  git commit -q -m "init" || exit 1

  print -r -- "STAGED" > only_staged.txt
  git add only_staged.txt || exit 1

  print -r -- "UNSTAGED" > only_unstaged.txt

  print -r -- "INDEX" > both.txt
  git add both.txt || exit 1
  print -r -- "WORKTREE" > both.txt
} || fail "setup temp git repo failed"

typeset staged_output=''
staged_output="$(
  cd "$tmp_dir" && {
    source "$REPO_ROOT/scripts/git/git-scope.zsh" || exit 1
    git-scope staged -p
  }
)" || fail "git-scope staged -p failed"

assert_contains \
  "$staged_output" \
  "📄 both.txt (index)" \
  "staged -p should print index for staged files" \
  || fail "missing index label for staged file"

assert_contains \
  "$staged_output" \
  "INDEX" \
  "staged -p should include staged content" \
  || fail "missing staged content"

assert_not_contains \
  "$staged_output" \
  "WORKTREE" \
  "staged -p should not print working tree content" \
  || fail "unexpected working tree content in staged output"

typeset all_output=''
all_output="$(
  cd "$tmp_dir" && {
    source "$REPO_ROOT/scripts/git/git-scope.zsh" || exit 1
    git-scope all -p
  }
)" || fail "git-scope all -p failed"

assert_contains \
  "$all_output" \
  "📄 only_staged.txt (index)" \
  "all -p should print index for staged-only files" \
  || fail "missing index print for staged-only file"

assert_not_contains \
  "$all_output" \
  "📄 only_staged.txt (working tree)" \
  "all -p should not print working tree for staged-only files" \
  || fail "unexpected worktree print for staged-only file"

assert_contains \
  "$all_output" \
  "📄 only_unstaged.txt (working tree)" \
  "all -p should print working tree for unstaged-only files" \
  || fail "missing worktree print for unstaged-only file"

assert_not_contains \
  "$all_output" \
  "📄 only_unstaged.txt (index)" \
  "all -p should not print index for unstaged-only files" \
  || fail "unexpected index print for unstaged-only file"

assert_contains \
  "$all_output" \
  "📄 both.txt (index)" \
  "all -p should print index for staged+unstaged files" \
  || fail "missing index print for staged+unstaged file"

assert_contains \
  "$all_output" \
  "📄 both.txt (working tree)" \
  "all -p should print working tree for staged+unstaged files" \
  || fail "missing worktree print for staged+unstaged file"

assert_contains \
  "$all_output" \
  "INDEX" \
  "all -p should include staged content for staged+unstaged files" \
  || fail "missing staged content in all output"

assert_contains \
  "$all_output" \
  "WORKTREE" \
  "all -p should include working tree content for staged+unstaged files" \
  || fail "missing worktree content in all output"

print -r -- "OK"

