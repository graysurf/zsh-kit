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

skip() {
  emulate -L zsh
  setopt pipe_fail nounset

  print -r -- "SKIP: $*"
  exit 0
}

if ! command -v git >/dev/null 2>&1; then
  skip "git not found"
fi

if ! command git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  skip "not a git worktree: $REPO_ROOT"
fi

typeset tracked_raw=''
tracked_raw="$(command git -C "$REPO_ROOT" ls-files -z 2>/dev/null)" || fail "git ls-files failed"
typeset -a tracked_files=("${(@0)tracked_raw}")

typeset -a forbidden_files=()
typeset file_path='' file_base=''
for file_path in "${tracked_files[@]}"; do
  file_base="${file_path:t}"
  case "$file_base" in
    .env)
      forbidden_files+=("$file_path")
      ;;
    .env.*)
      case "$file_base" in
        .env.example|.env.sample|.env.template) ;;
        *) forbidden_files+=("$file_path") ;;
      esac
      ;;
  esac
done

if (( ${#forbidden_files[@]} > 0 )); then
  print -u2 -r -- "Tracked dotenv files are forbidden (potential secrets):"
  for file_path in "${forbidden_files[@]}"; do
    print -u2 -r -- "  - $file_path"
  done
  print -u2 -r -- ""
  print -u2 -r -- "Fix:"
  print -u2 -r -- "  - command git rm --cached -- <file>"
  print -u2 -r -- "  - rotate any leaked secrets"
  exit 1
fi

print -r -- "OK"
