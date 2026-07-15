#!/usr/bin/env -S zsh -f

setopt pipe_fail nounset

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr TEST_DIR="${SCRIPT_PATH:h}"
typeset -gr REPO_ROOT="${TEST_DIR:h}"
typeset -gr TEST_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/zsh-kit-tests"
typeset -gr ZSH_BIN="$(command -v zsh)"

fail() {
  print -u2 -r -- "FAIL: $*"
  exit 1
}

typeset work_dir=''
mkdir -p -- "$TEST_ROOT" || fail "cannot create test root"
work_dir="$(mktemp -d "$TEST_ROOT/private-overlay-symlink.XXXXXX")" ||
  fail "mktemp failed"

{
  typeset ignore_repo="$work_dir/ignore-repo"
  mkdir -p -- "$ignore_repo/target"
  cp -- "$REPO_ROOT/.gitignore" "$ignore_repo/.gitignore"
  git -C "$ignore_repo" init -q
  ln -s target "$ignore_repo/.private"
  git -C "$ignore_repo" check-ignore --quiet .private ||
    fail ".gitignore does not cover the .private symlink itself"

  typeset home_dir="$work_dir/home"
  typeset zdotdir="$home_dir/.config/zsh"
  typeset canonical="$home_dir/Project/serenvia/local-scripts"
  mkdir -p -- "$zdotdir" "$canonical"
  print -r -- 'export PRIVATE_SYMLINK_ENV_LOADED=yes' >| "$canonical/zshenv.zsh"
  ln -s ../../Project/serenvia/local-scripts "$zdotdir/.private"

  typeset loaded=''
  loaded="$(HOME="$home_dir" ZDOTDIR="$zdotdir" TEST_REPO_ROOT="$REPO_ROOT" "$ZSH_BIN" -f -c 'source "$TEST_REPO_ROOT/.zshenv"; print -r -- "${PRIVATE_SYMLINK_ENV_LOADED:-no}"')"
  [[ "$loaded" == yes ]] || fail "valid relative private symlink did not load: $loaded"

  rm -- "$zdotdir/.private"
  ln -s ../../Project/serenvia/missing-local-scripts "$zdotdir/.private"
  typeset output='' rc=0
  output="$(HOME="$home_dir" ZDOTDIR="$zdotdir" TEST_REPO_ROOT="$REPO_ROOT" "$ZSH_BIN" -f -c 'source "$TEST_REPO_ROOT/.zshenv"' 2>&1)"
  rc=$?
  [[ "$rc" == 1 ]] || fail "broken private symlink should fail, got exit $rc"
  [[ "$output" == *'broken .private symlink'* ]] ||
    fail "broken private symlink diagnostic missing: $output"
  [[ -L "$zdotdir/.private" && ! -e "$zdotdir/.private" ]] ||
    fail "broken private symlink was replaced or removed"

  output="$(
    HOME="$home_dir" \
      ZDOTDIR="$zdotdir" \
      ZSH_PRIVATE_SCRIPT_DIR="$zdotdir/.private" \
      ZSH_BOOTSTRAP_SCRIPT_DIR="$REPO_ROOT/bootstrap" \
      TEST_REPO_ROOT="$REPO_ROOT" \
      "$ZSH_BIN" -f -c '
        source_file() { return 0 }
        source_file_warn_missing() { return 0 }
        load_script_group_ordered() { return 0 }
        source "$TEST_REPO_ROOT/bootstrap/bootstrap.zsh"
      ' 2>&1
  )"
  rc=$?
  [[ "$rc" == 1 ]] || fail "bootstrap should reject a broken private symlink, got exit $rc"
  [[ "$output" == *'broken .private symlink'* ]] ||
    fail "bootstrap broken-symlink diagnostic missing: $output"
  [[ -L "$zdotdir/.private" && ! -e "$zdotdir/.private" ]] ||
    fail "bootstrap replaced or removed the broken private symlink"

  typeset audit_repo="$work_dir/audit-repo"
  typeset audit_target="$work_dir/audit-target"
  mkdir -p -- "$audit_repo/tools" "$audit_target/_lib/shared/env"
  cp -- "$REPO_ROOT/tools/audit-env-bools.zsh" "$audit_repo/tools/"
  git -C "$audit_repo" init -q
  ln -s ../audit-target "$audit_repo/.private"
  typeset legacy_name='CODEX_ALLOW_''DANGEROUS'
  print -r -- "export ${legacy_name}=true" >| "$audit_target/_lib/shared/env/invalid.zsh"

  output="$(zsh -f -- "$audit_repo/tools/audit-env-bools.zsh" --check 2>&1)"
  rc=$?
  [[ "$rc" == 1 ]] ||
    fail "env audit did not traverse the private symlink: $output"
  [[ "$output" == *"legacy env name referenced: $legacy_name"* ]] ||
    fail "env audit missed symlinked private content: $output"

  print -r -- "OK"
} always {
  rm -rf -- "$work_dir"
}
