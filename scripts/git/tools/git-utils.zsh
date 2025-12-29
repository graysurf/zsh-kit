# ────────────────────────────────────────────────────────
# Git utility helpers
# ────────────────────────────────────────────────────────
if command -v safe_unalias >/dev/null; then
  safe_unalias \
    git-zip \
    git-copy-staged \
    git-root \
    get_commit_hash
fi

# git-zip
# Export `HEAD` as a zip file named by short hash.
# Usage: git-zip
# Notes:
# - Writes `backup-<sha>.zip` in the current directory.
git-zip() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  git archive --format zip HEAD -o "backup-$(git rev-parse --short HEAD).zip"
  return $?
}

# git-copy-staged [--stdout|--both]
# Copy staged diff to clipboard (default) or print to stdout.
# Usage: git-copy-staged [--stdout|--both]
# Notes:
# - Requires `set_clipboard` for clipboard mode.
# - Returns non-zero when there are no staged changes.
git-copy-staged() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset diff='' mode='clipboard' arg=''
  typeset -i mode_flags=0
  typeset -a extra_args=()

  while [[ $# -gt 0 ]]; do
    arg="${1-}"
    case "$arg" in
      --stdout|-p|--print)
        mode="stdout"
        (( mode_flags++ ))
        ;;
      --both)
        mode="both"
        (( mode_flags++ ))
        ;;
      --help|-h)
        print -r -- "Usage: git-copy-staged [--stdout|--both]"
        print -r -- "  --stdout   Print staged diff to stdout (no status message)"
        print -r -- "  --both     Print to stdout and copy to clipboard"
        return 0
        ;;
      *)
        extra_args+=("$arg")
        ;;
    esac
    shift
  done

  if (( mode_flags > 1 )); then
    print -u2 -r -- "❗ Only one output mode is allowed: --stdout or --both"
    return 1
  fi

  if (( ${#extra_args[@]} > 0 )); then
    print -u2 -r -- "❗ Unknown argument: ${extra_args[1]}"
    print -u2 -r -- "Usage: git-copy-staged [--stdout|--both]"
    return 1
  fi

  diff=$(git diff --cached --no-color)

  if [[ -z "$diff" ]]; then
    print -r -- "⚠️  No staged changes to copy"
    return 1
  fi

  if [[ "$mode" == "stdout" ]]; then
    printf "%s\n" "$diff"
    return 0
  fi

  printf "%s" "$diff" | set_clipboard

  if [[ "$mode" == "both" ]]; then
    printf "%s\n" "$diff"
  fi

  print -r -- "✅ Staged diff copied to clipboard"
  return 0
}

# git-root
# `cd` to the root directory of the current Git repository.
# Usage: git-root
# Notes:
# - Prints the resolved root path after changing directory.
git-root() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset root=''
  root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    print -u2 -r -- "❌ Not in a git repository"
    return 1
  }

  if ! cd "$root"; then
    print -u2 -r -- "❌ Failed to cd to git root: $root"
    return 1
  fi

  print -r -- ""
  print -r -- "📁 Jumped to Git root: $root"
  return 0
}

# get_commit_hash <ref>
# Print the commit SHA for a ref (supports annotated tags via `^{commit}`).
# Usage: get_commit_hash <ref>
# Output:
# - Prints the commit SHA to stdout.
get_commit_hash() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset ref="${1-}"
  if [[ -z "$ref" ]]; then
    print -u2 -r -- "❌ Missing git ref"
    return 1
  fi

  # Try resolve commit (handles annotated tags too)
  git rev-parse --verify --quiet "${ref}^{commit}"
  return $?
}
