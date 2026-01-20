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
tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t git-pick-test.XXXXXX)" || fail "mktemp failed"

{
  typeset origin_dir="$tmp_dir/origin.git"
  typeset repo_dir="$tmp_dir/repo"
  mkdir -p -- "$repo_dir" || fail "mkdir failed: $repo_dir"

  git init --bare -q -- "$origin_dir" || fail "git init --bare failed"
  (cd "$repo_dir" && git init -b main -q) || fail "git init failed"
  (cd "$repo_dir" && git config user.email test@example.com && git config user.name test) || fail "git config failed"
  (cd "$repo_dir" && git remote add origin "$origin_dir") || fail "git remote add origin failed"

  print -r -- "a" >| "$repo_dir/a.txt"
  (cd "$repo_dir" && git add a.txt && git commit -qm init) || fail "git commit failed"
  (cd "$repo_dir" && git push -u origin main -q) || fail "git push main failed"

  (cd "$repo_dir" && git checkout -b 'feature/pick-test' -q) || fail "git checkout -b feature/pick-test failed"
  print -r -- "one" >>| "$repo_dir/a.txt"
  (cd "$repo_dir" && git add a.txt && git commit -qm 'feat: one') || fail "git commit feat: one failed"
  print -r -- "two" >>| "$repo_dir/a.txt"
  (cd "$repo_dir" && git add a.txt && git commit -qm 'feat: two') || fail "git commit feat: two failed"

  typeset output='' rc=0
  output="$(
    cd "$repo_dir" && {
      source "$REPO_ROOT/scripts/git/tools/git-pick.zsh" || exit 1
      git-pick main HEAD~2..HEAD test
    } 2>&1
  )"
  rc=$?
  assert_eq 0 "$rc" "git-pick should succeed for HEAD~2..HEAD (resolved before branch switch)" || fail "$output"

  typeset branch=''
  branch="$(cd "$repo_dir" && git branch --show-current)" || fail "git branch --show-current failed"
  assert_eq "feature/pick-test" "$branch" "git-pick should switch back to original branch" || fail "branch=$branch"

  git --git-dir "$origin_dir" show-ref --verify --quiet "refs/heads/ci/main/test" \
    || fail "remote branch missing: ci/main/test"

  typeset -a subjects=()
  subjects=("${(@f)$(git --git-dir "$origin_dir" log -n 3 --pretty=%s ci/main/test)}")
  assert_eq "feat: two" "${subjects[1]-}" "remote branch tip should contain picked commit (feat: two)" || fail "subjects: ${(j:,:)subjects}"
  assert_eq "feat: one" "${subjects[2]-}" "remote branch should contain picked commit (feat: one)" || fail "subjects: ${(j:,:)subjects}"
  assert_eq "init" "${subjects[3]-}" "remote branch should be based on target (init)" || fail "subjects: ${(j:,:)subjects}"

  # Without --force, reusing the same CI branch should fail (local branch already exists).
  print -r -- "three" >>| "$repo_dir/a.txt"
  (cd "$repo_dir" && git add a.txt && git commit -qm 'feat: three') || fail "git commit feat: three failed"

  typeset output_no_force='' rc_no_force=0
  output_no_force="$(
    cd "$repo_dir" && {
      source "$REPO_ROOT/scripts/git/tools/git-pick.zsh" || exit 1
      git-pick main HEAD~3..HEAD test
    } 2>&1
  )"
  rc_no_force=$?
  if (( rc_no_force == 0 )); then
    fail "git-pick should fail when local ci branch exists without --force"
  fi
  [[ "$output_no_force" == *"Local branch already exists"* ]] || fail "unexpected output: $output_no_force"

  # With --force, it should rebuild/reset and include the new commit.
  typeset output_force='' rc_force=0
  output_force="$(
    cd "$repo_dir" && {
      source "$REPO_ROOT/scripts/git/tools/git-pick.zsh" || exit 1
      git-pick --force main HEAD~3..HEAD test
    } 2>&1
  )"
  rc_force=$?
  assert_eq 0 "$rc_force" "git-pick --force should succeed and update CI branch" || fail "$output_force"

  subjects=("${(@f)$(git --git-dir "$origin_dir" log -n 4 --pretty=%s ci/main/test)}")
  assert_eq "feat: three" "${subjects[1]-}" "remote branch tip should include new commit (feat: three)" || fail "subjects: ${(j:,:)subjects}"
  assert_eq "feat: two" "${subjects[2]-}" "remote branch should still include earlier commits" || fail "subjects: ${(j:,:)subjects}"
  assert_eq "feat: one" "${subjects[3]-}" "remote branch should still include earlier commits" || fail "subjects: ${(j:,:)subjects}"
  assert_eq "init" "${subjects[4]-}" "remote branch base should remain target" || fail "subjects: ${(j:,:)subjects}"

  branch="$(cd "$repo_dir" && git branch --show-current)" || fail "git branch --show-current failed"
  assert_eq "feature/pick-test" "$branch" "git-pick --force should switch back to original branch" || fail "branch=$branch"

  print -r -- "OK"
} always {
  rm -rf -- "$tmp_dir"
}

