#!/usr/bin/env -S zsh -f

setopt pipe_fail nounset

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr TEST_DIR="${SCRIPT_PATH:h}"
typeset -gr REPO_ROOT="${TEST_DIR:h}"
typeset -gr INSTALLER="$REPO_ROOT/bootstrap/install-tools.zsh"
typeset -gr ROOT_INSTALLER="$REPO_ROOT/install-tools.zsh"
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
}

typeset tmp_dir=''
tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t zsh-kit-install-tools-test.XXXXXX)" || fail "mktemp failed"

{
  mkdir -p -- "$tmp_dir/bin" "$tmp_dir/gnubin" "$tmp_dir/config" "$tmp_dir/cache"
  printf '%s\n' 'fake-tool::fake-tool::test tool' > "$tmp_dir/config/tools.list"
  : > "$tmp_dir/config/tools.macos.list"
  : > "$tmp_dir/config/tools.linux.list"
  : > "$tmp_dir/config/tools.optional.list"
  : > "$tmp_dir/config/tools.optional.macos.list"
  : > "$tmp_dir/config/tools.optional.linux.list"

  cat > "$tmp_dir/bin/brew" <<'EOF'
#!/bin/sh
if [ "$1" = "list" ] && [ "$2" = "--versions" ]; then
  exit 1
fi
if [ "$1" = "install" ]; then
  exit 42
fi
exit 0
EOF
  chmod +x "$tmp_dir/bin/brew"

  typeset output='' rc=0
  output="$(
    PATH="$tmp_dir/gnubin:/usr/bin" \
      _ZSH_INTERNAL_PATHS_EXPORTS_SOURCED=1 \
      ZDOTDIR="$REPO_ROOT" \
      ZSH_BOOTSTRAP_SCRIPT_DIR="$REPO_ROOT/bootstrap" \
      ZSH_CONFIG_DIR="$tmp_dir/config" \
      ZSH_CACHE_DIR="$tmp_dir/cache" \
      "$ZSH_BIN" -f -- "$ROOT_INSTALLER" --dry-run --quiet \
      2>&1
  )"
  rc=$?
  assert_eq 0 "$rc" "root wrapper dry-run should not depend on PATH zsh for delegation" || fail "$output"
  assert_contains "$output" "fake-tool" "root wrapper dry-run output" || fail "$output"

  output="$(
    PATH="$tmp_dir/bin:/usr/bin:/bin" \
      _ZSH_INTERNAL_PATHS_EXPORTS_SOURCED=1 \
      ZDOTDIR="$REPO_ROOT" \
      ZSH_CONFIG_DIR="$tmp_dir/config" \
      ZSH_CACHE_DIR="$tmp_dir/cache" \
      "$ZSH_BIN" -f -- "$INSTALLER" --quiet \
      2>&1 < /dev/null
  )"
  rc=$?
  assert_eq 1 "$rc" "noninteractive install without --yes should fail before installing" || fail "$output"
  assert_contains "$output" "Re-run with --yes" "noninteractive confirmation message" || fail "$output"

  output="$(
    PATH="$tmp_dir/bin:/usr/bin:/bin" \
      _ZSH_INTERNAL_PATHS_EXPORTS_SOURCED=1 \
      ZDOTDIR="$REPO_ROOT" \
      ZSH_CONFIG_DIR="$tmp_dir/config" \
      ZSH_CACHE_DIR="$tmp_dir/cache" \
      "$ZSH_BIN" -f -- "$INSTALLER" --quiet --yes \
      2>&1
  )"
  rc=$?
  assert_eq 1 "$rc" "failed brew install should return non-zero" || fail "$output"
  assert_contains "$output" "Failed to install fake-tool" "failed install output" || fail "$output"
  assert_contains "$output" "Failed:    1" "failed count output" || fail "$output"

  print -r -- "OK"
} always {
  rm -rf -- "$tmp_dir"
}
