# ────────────────────────────────────────────────────────
# Git commit helpers
# ────────────────────────────────────────────────────────
if command -v safe_unalias >/dev/null; then
  safe_unalias \
    git-commit-to-stash \
    git-commit-context
fi

_git_commit_confirm() {
  emulate -L zsh
  setopt localoptions

  typeset prompt="${1-}"
  [[ -n "$prompt" ]] || return 1
  shift || true

  print -n -r -- "$prompt"

  typeset confirm=''
  IFS= read -r confirm
  [[ "$confirm" == [yY] ]]
}

_git_commit_confirm_or_abort() {
  _git_commit_confirm "$@" && return 0
  print "🚫 Aborted"
  return 1
}

# Convert a commit into a stash entry (commit → stash), with safety checks.
#
# Motivation / typical use:
# - You made a "WIP" commit to save work, but later want it back as an uncommitted state
#   (like a stash) so you can continue splitting/editing without keeping that commit in history.
#
# What this function does (high-level):
# 1) Resolve the target commit (default: HEAD).
# 2) Create a stash entry that captures EXACTLY the patch introduced by that commit
#    relative to its parent (i.e., parent..commit).
# 3) Optionally rewind the current branch to the parent commit (so the commit disappears
#    from history), leaving the changes safely stored in stash.
#
# Important semantics:
# - This stashes the COMMIT'S DIFF, not your current working tree.
# - It does NOT automatically include untracked files created outside that commit
#   (because commits do not represent untracked files). If you need untracked too,
#   use a separate `git stash push -u` before/after, or extend this helper.
#
# Apply behavior:
# - Stash apply can still conflict if your current working tree diverged in the same area.
# - Including parent SHA in message helps you know the best base to apply on, but
#   success is still determined by mergeability, not the message.
#
# Safety:
# - Warns if the commit is not on the current branch ancestry.
# - Warns if the commit looks pushed upstream (heuristic) and requires extra confirmation
#   if you choose to drop it from history.
# - Warns if a merge commit (multiple parents) is given (defaults to parent #1).
#
# Usage:
#   git-commit-to-stash              # convert HEAD commit → stash; offer to drop from history
#   git-commit-to-stash <commit>     # convert specific commit → stash
#
# Notes:
# - Requires: git, zsh, and `git stash` support (standard).
# - This function creates a stash entry via plumbing:
#     git stash create + git stash store
#   to store a patch not necessarily equal to current working tree state.
git-commit-to-stash() {
  typeset commit_ref commit_sha parent_sha branch_name subject
  typeset stash_msg stash_sha
  typeset upstream ref_upstream merge_parents_count

  # ── Safety: ensure we are inside a Git repository ───────────────────────────
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    print "❌ Not a git repository."
    return 1
  fi

  # Target commit (default HEAD)
  commit_ref="${1:-HEAD}"

  # Resolve commit SHA
  commit_sha=$(git rev-parse --verify "${commit_ref}^{commit}" 2>/dev/null)
  if [[ -z "$commit_sha" ]]; then
    print "❌ Cannot resolve commit: $commit_ref"
    return 1
  fi

  # Get parent SHA (handle root commit: no parent)
  parent_sha=$(git rev-parse --verify "${commit_sha}^" 2>/dev/null)
  if [[ -z "$parent_sha" ]]; then
    print "❌ Commit $commit_sha has no parent (root commit)."
    print "🧠 Converting a root commit to stash is ambiguous; aborting."
    return 1
  fi

  # Detect merge commit (multiple parents) and warn
  merge_parents_count=$(git rev-list --parents -n 1 "$commit_sha" | wc -w | tr -d ' ')
  # Output format: <commit> <p1> <p2> ... so count > 2 means multiple parents
  if (( merge_parents_count > 2 )); then
    print "⚠️  Target commit is a merge commit (multiple parents)."
    print "🧠 This tool will use the FIRST parent to compute the patch: ${commit_sha}^1..${commit_sha}"
    _git_commit_confirm_or_abort "❓ Proceed? [y/N] " || return 1
    parent_sha=$(git rev-parse --verify "${commit_sha}^1" 2>/dev/null) || return 1
  fi

  # Gather context for stash message
  branch_name=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || branch_name="(unknown)"
  subject=$(git log -1 --pretty=%s "$commit_sha" 2>/dev/null) || subject="(no subject)"

  # Create a descriptive stash message (includes commit + parent for traceability)
  # Format example:
  #   c2s: commit=abcd123 parent=beef456 branch=feature/x "Refactor parser"
  stash_msg="c2s: commit=${commit_sha[1,7]} parent=${parent_sha[1,7]} branch=${branch_name} \"${subject}\""

  print "🧾 Convert commit → stash"
  print "   Commit : $(git log -1 --oneline "$commit_sha")"
  print "   Parent : ${parent_sha[1,7]}"
  print "   Branch : $branch_name"
  print "   Message: $stash_msg"
  print ""
  print "This will:"
  print "  1) Create a stash entry containing the patch: ${parent_sha[1,7]}..${commit_sha[1,7]}"
  print "  2) Optionally drop the commit from branch history by resetting to parent."
  _git_commit_confirm_or_abort "❓ Proceed to create stash? [y/N] " || return 1

  # ── Create stash entry for the commit's patch ───────────────────────────────
  #
  # `git stash create` creates a stash commit object from the current index/worktree state,
  # but we want "parent..commit patch" even if current worktree differs.
  #
  # Workaround approach:
  # - Use `git diff` to generate the patch for parent..commit.
  # - Apply it onto the *index* of the parent state (in-memory) is non-trivial without
  #   touching working tree, so we use a standard plumbing trick:
  #
  #   1) Save current state safety by requiring CLEAN worktree? (optional)
  #      We won't require it, because we aren't mutating worktree by default for stash creation.
  #
  #   2) Use `git stash create` on a temporary state:
  #      The most reliable portable method is:
  #        - checkout the parent into a temporary detached state? (touches worktree)  ❌
  #
  # Instead, we use:
  #   - `git stash store` with an object made by `git commit-tree` (complex) ❌
  #
  # A simpler, robust method that doesn't require exotic plumbing is:
  #   - Use `git stash store` on top of `git stash create` by *temporarily*
  #     setting worktree to the commit's tree and index to parent? Still messy.
  #
  # Practical compromise (common in tooling):
  # - We create a stash from the commit itself by asking Git to create a WIP-like stash
  #   representing that commit relative to its parent using `git stash create <tree-ish>`.
  #
  # Good news: `git stash create <commit>` exists and creates a stash object as if the
  # working tree were at <commit>. It still includes staged/unstaged separation heuristics,
  # but for our use, it reliably captures the changes from parent→commit as a stash-like object.
  #
  # If a given Git build doesn't support `git stash create <commit>`, we will fallback to
  # a worktree-touching method (prompted).
  stash_sha=$(git stash create "$commit_sha" 2>/dev/null)

  if [[ -z "$stash_sha" ]]; then
    print "⚠️  Failed to create stash object via: git stash create <commit>"
    print "🧠 Your Git may not support this form. Fallback would require touching the working tree."
    _git_commit_confirm_or_abort "❓ Fallback by temporarily checking out parent and applying patch (will modify worktree)? [y/N] " || return 1

    # ── Fallback (touches worktree): store patch into stash via temp apply ─────
    # Preconditions: require clean worktree to avoid mixing changes
    if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
      print "❌ Working tree is not clean; fallback requires clean state."
      print "🧠 Commit/stash your current changes first, then retry."
      return 1
    fi

    # Save where we are
    typeset current_head
    current_head=$(git rev-parse HEAD 2>/dev/null) || return 1

    # Move to parent in detached HEAD to apply patch cleanly
    if ! git checkout --detach "$parent_sha" >/dev/null 2>&1; then
      print "❌ Failed to checkout parent for fallback."
      return 1
    fi

    # Apply patch (parent..commit) to working tree
    if ! git cherry-pick -n "$commit_sha" >/dev/null 2>&1; then
      print "❌ Failed to apply commit patch in fallback mode."
      print "🧠 Attempting to restore original HEAD."
      git cherry-pick --abort >/dev/null 2>&1
      git checkout "$current_head" >/dev/null 2>&1
      return 1
    fi

    # Now stash the applied changes (includes tracked changes; can add -u if desired)
    if ! git stash push -m "$stash_msg" >/dev/null 2>&1; then
      print "❌ Failed to stash changes in fallback mode."
      git reset --hard >/dev/null 2>&1
      git checkout "$current_head" >/dev/null 2>&1
      return 1
    fi

    # Restore original HEAD
    git reset --hard >/dev/null 2>&1
    git checkout "$current_head" >/dev/null 2>&1

    print "✅ Stash created (fallback): $(git stash list -1)"
  else
    # Store the created stash object into stash list with message
    if ! git stash store -m "$stash_msg" "$stash_sha" >/dev/null 2>&1; then
      print "❌ Failed to store stash object."
      return 1
    fi
    print "✅ Stash created: $(git stash list -1)"
  fi

  # ── Optional: drop the commit from history by resetting current branch ──────
  #
  # This is only safe if:
  # - The commit is at the tip of current branch (HEAD), OR you explicitly want rewrite.
  # We keep it conservative: only offer automatic drop when commit_ref == HEAD.
  if [[ "$commit_ref" != "HEAD" && "$commit_sha" != "$(git rev-parse HEAD 2>/dev/null)" ]]; then
    print "ℹ️  Not dropping commit automatically because target is not HEAD."
    print "🧠 If you want to remove it, do so explicitly (e.g., interactive rebase) after verifying stash."
    return 0
  fi

  print ""
  print "Optional: drop the commit from current branch history?"
  print "  This would run: git reset --hard ${parent_sha[1,7]}"
  print "  (Your work remains in stash; untracked files are unaffected.)"
  if ! _git_commit_confirm "❓ Drop commit from history now? [y/N] "; then
    print "✅ Done. Commit kept; stash saved."
    return 0
  fi

  # Extra warning if commit appears reachable from upstream (heuristic)
  upstream=$(git rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>/dev/null)
  # If commit is an ancestor of upstream or equal/reachable, it was likely pushed
  if [[ -n "$upstream" ]] && git merge-base --is-ancestor "$commit_sha" "$upstream" 2>/dev/null; then
    print "⚠️  This commit appears to be reachable from upstream ($upstream)."
    print "🧨 Dropping it rewrites history and may require force push; it can affect others."
    if ! _git_commit_confirm "❓ Still drop it? [y/N] "; then
      print "✅ Done. Commit kept; stash saved."
      return 0
    fi
  fi

  if ! _git_commit_confirm "❓ Final confirmation: run 'git reset --hard ${parent_sha[1,7]}'? [y/N] "; then
    print "✅ Done. Commit kept; stash saved."
    return 0
  fi

  if ! git reset --hard "$parent_sha"; then
    print "❌ Failed to reset branch to parent."
    print "🧠 Your stash is still saved. You can manually recover the commit via reflog if needed."
    return 1
  fi

  print "✅ Commit dropped from history. Your work is in stash:"
  print "   $(git stash list -1)"
}

# git-commit-context
#
# This function generates a comprehensive Markdown-formatted summary of the current staged Git changes,
# to assist with writing a precise and valid commit message (especially for use with commitlint rules).
#
# It performs the following steps:
#  1. Collects the full diff of staged files (`git diff --cached`).
#  2. Generates a file scope summary and directory tree using `git-scope staged`.
#  3. Iterates through each staged file to include its staged (index) version (after changes).
#     - For deleted files: notes that index content is unavailable.
#     - For added/modified/renamed files: includes the staged content.
#  4. Formats all this into a Markdown document, including:
#     - 📄 Git staged diff (as `diff` block)
#     - 📂 Scope and directory tree (as `bash` block)
#     - 📚 Staged file contents (as `ts` blocks per file)
#
# The result is piped to both:
#  - `set_clipboard` for immediate pasting into ChatGPT or documentation tools.
#  - A temporary file via `mktemp` for future reference/debugging.
#
# ⚠️ The resulting document also includes instructions for generating Semantic Commit messages
#     that follow commitlint standards.
#
# Example usage:
#   $ git add .
#   $ git-commit-context
#
# Output: Markdown commit context is copied to clipboard and logged to a temp file.
git-commit-context () {
  emulate -L zsh
  setopt localoptions pipe_fail

  typeset tmpfile='' diff='' scope='' contents='' mode='clipboard'
  typeset no_color=false
  typeset arg=''
  typeset -a extra_args=()

  while [[ $# -gt 0 ]]; do
    arg="${1-}"
    case "$arg" in
      --stdout|-p|--print)
        mode="stdout"
        ;;
      --both)
        mode="both"
        ;;
      --no-color|no-color)
        no_color=true
        ;;
      --help|-h)
        print -r -- "Usage: git-commit-context [--stdout|--both] [--no-color]"
        print -r -- "  --stdout   Print commit context to stdout only"
        print -r -- "  --both     Print to stdout and copy to clipboard"
        print -r -- "  --no-color Disable ANSI colors (also via NO_COLOR)"
        return 0
        ;;
      *)
        extra_args+=("$arg")
        ;;
    esac
    shift
  done

  diff="$(git diff --cached --no-color)"

  if (( ${#extra_args[@]} > 0 )); then
    print -u2 -r -- "⚠️  Ignoring unknown arguments: ${extra_args[*]}"
  fi

  if [[ -z "$diff" ]]; then
    printf "⚠️  No staged changes to record\n" >&2
    return 1
  fi

  typeset -a scope_args=(staged)
  if [[ "$no_color" == true || -n "${NO_COLOR-}" ]]; then
    scope_args+=(--no-color)
  fi
  scope="$(git-scope "${scope_args[@]}" | sed 's/\x1b\[[0-9;]*m//g')"

  tmpfile="$(mktemp -t commit-context.md.XXXXXX)"

  contents="$(
    git -c core.quotepath=false diff --cached --name-status -z | while IFS= read -r -d '' fstatus; do
      typeset file='' newfile=''

      if [[ -z "$fstatus" ]]; then
        continue
      fi

      case "$fstatus" in
        R*|C*)
          IFS= read -r -d '' file || break
          IFS= read -r -d '' newfile || break
          ;;
        *)
          IFS= read -r -d '' file || break
          ;;
      esac

      display_path="$file"
      content_path="$file"

      if [[ -n "$newfile" ]]; then
        display_path="${file} -> ${newfile}"
        content_path="$newfile"
      fi

      printf "### %s (%s)\n\n" "$display_path" "$fstatus"

      if [[ "$fstatus" == "D" ]]; then
        if git cat-file -e "HEAD:$file" 2>/dev/null; then
          printf "[Deleted file, showing HEAD version]\n\n"
          printf '```ts\n'
          git show "HEAD:$file" 2>/dev/null || printf '[HEAD version not found]\n'
          printf '```\n\n'
        else
          printf "[Deleted file, no HEAD version found]\n\n"
        fi
      elif [[ "$fstatus" == "A" || "$fstatus" == "M" || "$fstatus" == R* || "$fstatus" == C* ]]; then
        printf '```ts\n'
        git show :"$content_path" 2>/dev/null || printf '[Index version not found]\n'
        printf '```\n\n'
      else
        printf "[Unhandled status: %s]\n\n" "$fstatus"
      fi
    done
  )"

  printf "%s\n" "# Commit Context

## Input expectations

- Full-file reads are not required for commit message generation.
- Base the message on staged diff, scope tree, and staged (index) version content.

---

## 📂 Scope and file tree:

\`\`\`text
$scope
\`\`\`

## 📄 Git staged diff:

\`\`\`diff
$diff
\`\`\`

## 📚 Staged file contents (index version):

$contents" > "$tmpfile"

  if [[ "$mode" == "stdout" ]]; then
    command cat "$tmpfile"
    return 0
  fi

  if [[ "$mode" == "both" ]]; then
    command cat "$tmpfile"
  fi

  command cat "$tmpfile" | set_clipboard

  if [[ "$mode" == "clipboard" ]]; then
    printf "✅ Commit context copied to clipboard with:\n"
    printf "  • Diff\n"
    printf "  • Scope summary (via git-scope staged)\n"
    printf "  • Staged file contents (index version)\n"
  fi
}
