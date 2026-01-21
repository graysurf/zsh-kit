#!/usr/bin/env -S zsh -f

setopt pipe_fail nounset

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr TEST_DIR="${SCRIPT_PATH:h}"
typeset -gr REPO_ROOT="${TEST_DIR:h}"
typeset -gr PRELOAD_SCRIPT="$REPO_ROOT/bootstrap/00-preload.zsh"
typeset -gr FETCHER_SCRIPT="$REPO_ROOT/bootstrap/plugin_fetcher.zsh"

fail() {
  emulate -L zsh
  setopt pipe_fail nounset

  print -u2 -r -- "FAIL: $*"
  exit 1
}

typeset tmp_dir=''
tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t zsh-kit-plugin-fetcher-test.XXXXXX)" || fail "mktemp failed"

typeset plugins_dir="$tmp_dir/plugins"
mkdir -p -- "$plugins_dir" || fail "failed to create plugins dir"
print -r -- "sentinel" >| "$plugins_dir/keep.txt" || fail "failed to write sentinel"

typeset -x ZSH_PLUGINS_DIR="$plugins_dir"
typeset -x PLUGIN_FETCH_FORCE_ENABLED=true
typeset -x PLUGIN_FETCH_DRY_RUN_ENABLED=false

[[ -f "$PRELOAD_SCRIPT" ]] || fail "missing preload script: $PRELOAD_SCRIPT"
source "$PRELOAD_SCRIPT"

[[ -f "$FETCHER_SCRIPT" ]] || fail "missing fetcher script: $FETCHER_SCRIPT"
source "$FETCHER_SCRIPT"

plugin_fetch_if_missing_from_entry "::git=https://example.com/repo.git" && fail "expected invalid entry to fail"
[[ -d "$plugins_dir" ]] || fail "plugins dir should remain after invalid entry"
[[ -f "$plugins_dir/keep.txt" ]] || fail "sentinel should remain after invalid entry"

plugin_fetch_if_missing_from_entry "   " && fail "expected whitespace entry to fail"
[[ -d "$plugins_dir" ]] || fail "plugins dir should remain after whitespace entry"
[[ -f "$plugins_dir/keep.txt" ]] || fail "sentinel should remain after whitespace entry"
