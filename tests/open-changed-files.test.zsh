#!/usr/bin/env -S zsh -f

setopt pipe_fail nounset

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr TEST_DIR="${SCRIPT_PATH:h}"
typeset -gr REPO_ROOT="${TEST_DIR:h}"
typeset -gr TOOL_SCRIPT="$REPO_ROOT/tools/open-changed-files.zsh"
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

assert_not_contains() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset haystack="$1" needle="$2" context="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    print -u2 -r -- "Unexpected substring: $needle"
    print -u2 -r -- "Context           : $context"
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
tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t open-changed-files-test.XXXXXX)" || fail "mktemp failed"

{
  typeset pwd_ws="$tmp_dir/pwd-workspace"
  mkdir -p -- "$pwd_ws" || fail "mkdir failed: $pwd_ws"

  typeset file1="$tmp_dir/file1.txt"
  typeset file2="$tmp_dir/dir/file2.txt"
  typeset file3="$tmp_dir/file3.txt"
  mkdir -p -- "${file2:h}" || fail "mkdir failed: ${file2:h}"
  print -r -- "one" >| "$file1"
  print -r -- "two" >| "$file2"
  print -r -- "three" >| "$file3"

  typeset pwd_ws_abs="${pwd_ws:A}"
  typeset file1_abs="${file1:A}"
  typeset file2_abs="${file2:A}"
  typeset file3_abs="${file3:A}"

  # --dry-run prints a planned invocation (default workspace-mode: pwd).
  typeset output='' rc=0 expected=''
  output="$(cd "$pwd_ws" && "$ZSH_BIN" -f -- "$TOOL_SCRIPT" --dry-run "$file1_abs" "$file2_abs" 2>&1)"
  rc=$?
  assert_eq 0 "$rc" "dry-run should exit 0" || fail "$output"
  assert_contains_all "$output" "dry-run output should include expected args" \
    "--new-window" \
    "-- $pwd_ws_abs $file1_abs $file2_abs" || fail "$output"

  # --max-files should cap opened files.
  output="$(cd "$pwd_ws" && "$ZSH_BIN" -f -- "$TOOL_SCRIPT" --dry-run --max-files 2 "$file1_abs" "$file2_abs" "$file3_abs" 2>&1)"
  rc=$?
  assert_eq 0 "$rc" "--max-files should exit 0" || fail "$output"
  assert_contains "$output" "$file1_abs" "max-files should keep first file" || fail "$output"
  assert_contains "$output" "$file2_abs" "max-files should keep second file" || fail "$output"
  assert_not_contains "$output" "$file3_abs" "max-files should drop extra files" || fail "$output"

  # --verbose should explain skipped paths on stderr.
  typeset missing="$tmp_dir/missing.txt"
  output="$(cd "$pwd_ws" && "$ZSH_BIN" -f -- "$TOOL_SCRIPT" --dry-run --verbose "$missing" "$file1_abs" 2>&1)"
  rc=$?
  assert_eq 0 "$rc" "--verbose should still exit 0" || fail "$output"
  assert_contains "$output" "skip: not a file:" "verbose should log skipped path" || fail "$output"
  assert_contains "$output" "$file1_abs" "verbose should still include valid files" || fail "$output"

  # Normal mode should be a silent no-op when `code` is missing.
  output="$(OPEN_CHANGED_FILES_CODE_PATH=none "$ZSH_BIN" -f -- "$TOOL_SCRIPT" "$file1_abs" 2>&1)"
  rc=$?
  assert_eq 0 "$rc" "missing code should exit 0" || fail "$output"
  assert_eq "" "$output" "missing code should be silent" || fail "$output"

  # Normal mode should be a silent no-op when `OPEN_CHANGED_FILES_CODE_PATH` is invalid.
  typeset missing_code="$tmp_dir/missing-code"
  output="$(OPEN_CHANGED_FILES_CODE_PATH="$missing_code" "$ZSH_BIN" -f -- "$TOOL_SCRIPT" "$file1_abs" 2>&1)"
  rc=$?
  assert_eq 0 "$rc" "invalid code override should exit 0" || fail "$output"
  assert_eq "" "$output" "invalid code override should be silent" || fail "$output"

  # --verbose should explain invalid code override.
  output="$(OPEN_CHANGED_FILES_CODE_PATH="$missing_code" "$ZSH_BIN" -f -- "$TOOL_SCRIPT" --verbose "$file1_abs" 2>&1)"
  rc=$?
  assert_eq 0 "$rc" "invalid code override (verbose) should exit 0" || fail "$output"
  assert_contains "$output" "no-op: code override not found:" "verbose should log invalid code override" || fail "$output"

  # workspace-mode=git should group files by nearest `.git` root.
  typeset git1="$tmp_dir/git1"
  typeset git2="$tmp_dir/git2"
  mkdir -p -- "$git1/.git" "$git2/.git" "$git1/sub" "$git2/sub" || fail "mkdir failed for git roots"
  typeset g1_file="$git1/sub/a.txt"
  typeset g2_file="$git2/sub/b.txt"
  print -r -- "a" >| "$g1_file"
  print -r -- "b" >| "$g2_file"
  typeset git1_abs="${git1:A}"
  typeset git2_abs="${git2:A}"
  typeset g1_abs="${g1_file:A}"
  typeset g2_abs="${g2_file:A}"

  output="$(cd "$pwd_ws" && "$ZSH_BIN" -f -- "$TOOL_SCRIPT" --dry-run --workspace-mode git "$g1_abs" "$g2_abs" 2>&1)"
  rc=$?
  assert_eq 0 "$rc" "workspace-mode git should exit 0" || fail "$output"
  typeset -a invocations=("${(@f)output}")
  assert_eq 2 "${#invocations[@]}" "workspace-mode git should print two invocations" || fail "$output"
  assert_contains_all "${invocations[1]}" "workspace-mode git (first root) should include expected args" \
    "--new-window" \
    "-- $git1_abs $g1_abs" || fail "${invocations[1]}"
  assert_contains_all "${invocations[2]}" "workspace-mode git (second root) should include expected args" \
    "--new-window" \
    "-- $git2_abs $g2_abs" || fail "${invocations[2]}"

  # Normal mode should batch and reuse the same window per workspace.
  typeset bin_dir="$tmp_dir/bin"
  mkdir -p -- "$bin_dir" || fail "mkdir failed: $bin_dir"
  typeset code_log="$tmp_dir/code.log"
  : >| "$code_log"

  typeset code_stub="$bin_dir/code"
  {
    print -r -- '#!/usr/bin/env -S zsh -f'
    print -r -- 'setopt pipe_fail err_exit nounset'
    print -r -- 'typeset log_file="${CODE_LOG_FILE:?}"'
    print -r -- 'print -r -- "${(j: :)${(@q)argv}}" >>| "$log_file"'
    print -r -- 'exit 0'
  } >| "$code_stub"
  chmod 755 "$code_stub"

  typeset -a many_files=()
  typeset -i i=0
  for i in {1..55}; do
    typeset f="$tmp_dir/many/$i.txt"
    mkdir -p -- "${f:h}" || fail "mkdir failed: ${f:h}"
    print -r -- "$i" >| "$f"
    many_files+=("${f:A}")
  done

  (cd "$pwd_ws" && CODE_LOG_FILE="$code_log" PATH="$bin_dir:$PATH" \
    "$ZSH_BIN" -f -- "$TOOL_SCRIPT" --max-files 55 "${many_files[@]}") || fail "normal mode should exit 0"

  typeset -a invocations=("${(@f)$(command cat -- "$code_log")}")
  assert_eq 2 "${#invocations[@]}" "should invoke code twice (50 + 5)" || fail "$(command cat -- "$code_log")"
  assert_contains "${invocations[1]}" "--new-window" "first batch should use --new-window" || fail "${invocations[1]}"
  assert_contains "${invocations[1]}" "$pwd_ws_abs" "first batch should include workspace dir" || fail "${invocations[1]}"
  assert_contains "${invocations[2]}" "--reuse-window" "second batch should use --reuse-window" || fail "${invocations[2]}"
  assert_contains "${invocations[2]}" "$pwd_ws_abs" "second batch should include workspace dir" || fail "${invocations[2]}"
  assert_contains "${invocations[1]}" "${many_files[1]}" "first batch should include first file" || fail "${invocations[1]}"
  assert_contains "${invocations[2]}" "${many_files[-1]}" "second batch should include last file" || fail "${invocations[2]}"

  print -r -- "OK"
} always {
  rm -rf -- "$tmp_dir"
}
