# ────────────────────────────────────────────────────────
# Aliases and Unalias
# ────────────────────────────────────────────────────────
if command -v safe_unalias >/dev/null; then
  safe_unalias \
    gr grs grm grh \
    gbh gbc gdb gdbs \
    gdc groot \
    gop god goc gob \
    gh-open \
    gh-open-branch \
    gh-open-default-branch \
    gh-open-commit \
    gh-push-open \
    git-commit-context gcc \
    git-reset-hard \
    git-reset-soft \
    git-reset-mixed \
    git-reset-undo \
    git-back-head \
    git-back-checkout \
    git-delete-merged-branches \
    git-zip \
    get_commit_hash
fi

# ────────────────────────────────────────────────────────
# Git operation aliases
# ────────────────────────────────────────────────────────

# Export current HEAD as zip file named by short hash (e.g. backup-a1b2c3d.zip)
alias git-zip='git archive --format zip HEAD -o "backup-$(git rev-parse --short HEAD).zip"'

# Reset staged files (equivalent to "git reset")
alias gr='git reset'

# Copy staged diff to clipboard (default) or print to stdout for LLM usage.
gdc() {
  typeset diff mode
  typeset -i mode_flags=0
  typeset -a extra_args=()
  mode="clipboard"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --stdout|-p|--print)
        mode="stdout"
        (( mode_flags++ ))
        ;;
      --both)
        mode="both"
        (( mode_flags++ ))
        ;;
      --help|-h)
        print "Usage: gdc [--stdout|--both]"
        print "  --stdout   Print staged diff to stdout (no status message)"
        print "  --both     Print to stdout and copy to clipboard"
        return 0
        ;;
      *)
        extra_args+=("$1")
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
    print -u2 -r -- "Usage: gdc [--stdout|--both]"
    return 1
  fi

  diff=$(git diff --cached --no-color)

  if [[ -z "$diff" ]]; then
    print "⚠️  No staged changes to copy"
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

  print "✅ Staged diff copied to clipboard"
}

# Jump to the root directory of the current Git repository
groot() {
  typeset root
  root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    print "❌ Not in a git repository"
    return 1
  }
  cd "$root" && print "\n 📁 Jumped to Git root: $root"
}

# get_commit_hash <ref>
get_commit_hash() {
  typeset ref="$1"
  if [[ -z "$ref" ]]; then
    print "❌ Missing git ref" >&2
    return 1
  fi

  # Try resolve commit (handles annotated tags too)
  git rev-parse --verify --quiet "${ref}^{commit}"
}

# ────────────────────────────────────────────────────────
# Git workflow helper functions
# ────────────────────────────────────────────────────────

# Undo the last commit while keeping all changes staged (soft reset)
#
# This function performs a `git reset --soft HEAD~1`, which removes the
# last commit from history but keeps all changes staged. This is useful
# when you want to rewrite the commit message or make additional edits
# before recommitting.
#
# It is a safer alternative to hard resets and preserves your working state.
git-reset-soft() {
  print "⚠️  This will rewind your last commit (soft reset)"
  print "🧠 Your changes will remain STAGED. Useful for rewriting commit message."
  print -n "❓ Proceed with 'git reset --soft HEAD~1'? [y/N] "
  read -r confirm
  if [[ "$confirm" != [yY] ]]; then
    print "🚫 Aborted"
    return 1
  fi

  git reset --soft HEAD~1
  if [[ $? -ne 0 ]]; then
    print "❌ Soft reset failed (no parent commit, or invalid HEAD state)."
    return 1
  fi

  print "✅ Last commit undone. Your changes are still staged."
}

# Hard reset to the previous commit with confirmation (DANGEROUS)
#
# This function performs a `git reset --hard HEAD~1`, which removes the last
# commit and discards all staged and unstaged changes for tracked files by
# synchronizing HEAD, index, and working tree to the previous commit.
#
# ⚠️ WARNING: This operation is destructive for uncommitted tracked changes.
# - The removed commit can often be recovered via `git reflog`, but uncommitted
#   tracked edits overwritten by `--hard` may be difficult or impossible to restore.
# - Untracked files are NOT removed by `git reset --hard` (use `git clean` if needed).
git-reset-hard() {
  print "⚠️  This will HARD RESET your repository to the previous commit."
  print "🔥 Tracked staged/unstaged changes will be OVERWRITTEN."
  print "🧨 This is equivalent to: git reset --hard HEAD~1"
  print -n "❓ Are you absolutely sure? [y/N] "
  read -r confirm
  if [[ "$confirm" != [yY] ]]; then
    print "🚫 Aborted"
    return 1
  fi

  git reset --hard HEAD~1
  if [[ $? -ne 0 ]]; then
    print "❌ Hard reset failed (no parent commit, or invalid HEAD state)."
    return 1
  fi

  # Note: Untracked files may still exist; `git status` may not be clean.
  print "✅ Hard reset completed. HEAD moved back one commit."
}

# Undo the last commit and unstage all changes (mixed reset)
#
# This function performs a `git reset --mixed HEAD~1`, which removes the
# last commit and moves all associated changes into the working directory
# in an unstaged state. This is useful when you want to revise changes
# more freely before recommitting.
#
# This is Git's default reset mode if no flag is given.
git-reset-mixed() {
  print "⚠️  This will rewind your last commit (mixed reset)"
  print "🧠 Your changes will become UNSTAGED and editable in working directory."
  print -n "❓ Proceed with 'git reset --mixed HEAD~1'? [y/N] "
  read -r confirm
  if [[ "$confirm" != [yY] ]]; then
    print "🚫 Aborted"
    return 1
  fi

  git reset --mixed HEAD~1
  if [[ $? -ne 0 ]]; then
    print "❌ Mixed reset failed (no parent commit, or invalid HEAD state)."
    return 1
  fi

  print "✅ Last commit undone. Your changes are now unstaged."
}

# Undo the last HEAD move using reflog (safer "back one step" with staged/unstaged choices)
#
# This function restores the repository to the previous HEAD position using reflog:
#   - Target: HEAD@{1}  (the previous HEAD position)
#
# It adds safety layers by distinguishing:
#   - HEAD@{0}: the CURRENT HEAD reflog entry (describes the LAST action that moved HEAD to *current* state)
#   - HEAD@{1}: the TARGET previous HEAD position (where we want to go back to)
#
# Why check HEAD@{0} (current action) instead of HEAD@{1}?
# - If you just ran `git reset`, the reflog subject for HEAD@{0} typically starts with `reset: ...`.
# - HEAD@{1}'s subject describes an earlier movement (often commit/checkout), which can be misleading for
#   determining what you "just did". Since this is an "undo last move" helper, HEAD@{0} is the right signal.
#
# Why reset to a resolved SHA ($target_commit) instead of using HEAD@{1} directly?
# - This function is interactive: it prints the target commit and waits for user input.
# - Using the resolved SHA guarantees "preview == action" even if reflog changes during the prompt
#   (e.g., external tools writing reflog entries). It makes behavior deterministic and consistent.
#
# Reflog display portability:
# - Many environments accept `HEAD@{0}` / `HEAD@{1}` directly in `git reflog`.
# - For maximum robustness, this function includes a fallback using `git reflog show` if the direct
#   form fails (e.g., unusual wrappers or edge environments). Fallback is informational only.
#
# Optional safety: detect in-progress operations
# - If you are in the middle of merge/rebase/cherry-pick/revert/bisect, users often actually want an
#   abort command instead of moving HEAD with reset. This function warns and asks for confirmation.
#
# Local-change awareness (tracked + untracked):
# - If working tree is clean (no staged/unstaged/untracked changes), it runs:
#     git reset --hard <target_commit>
# - If changes exist, it offers explicit choices:
#     1) Keep changes + PRESERVE INDEX (staged reinterpreted vs new base) -> git reset --soft  <target_commit>
#     2) Keep changes + UNSTAGE ALL                                -> git reset --mixed <target_commit>
#     3) Discard tracked changes                                   -> git reset --hard  <target_commit>
#     4) Abort
#
# Notes:
# - `git reset --hard` does NOT remove untracked files; use `git clean` if needed.
# - HEAD@{1} is "previous HEAD position", not necessarily "previous reset".
# - If you already pushed rewritten history, resetting locally may require force push and can impact others.
git-reset-undo() {
  typeset target_commit
  typeset status_lines
  typeset reflog_line_current reflog_subject_current
  typeset reflog_line_target  reflog_subject_target
  typeset choice confirm_non_reset confirm
  typeset -a op_warnings

  # ── Safety: ensure we are inside a Git repository ───────────────────────────
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    print "❌ Not a git repository."
    return 1
  fi

  # Resolve the TARGET commit (previous HEAD position) to a stable SHA.
  # We intentionally capture the SHA early so the action later is deterministic.
  target_commit=$(git rev-parse HEAD@{1} 2>/dev/null)
  if [[ -z "$target_commit" ]]; then
    print "❌ Cannot resolve HEAD@{1} (no previous HEAD position in reflog)."
    return 1
  fi

  # ── Optional safety: detect in-progress operations (merge/rebase/etc.) ──────
  op_warnings=()

  # merge in progress
  [[ -f "$(git rev-parse --git-path MERGE_HEAD 2>/dev/null)" ]] \
    && op_warnings+=("merge in progress (suggest: git merge --abort)")

  # rebase in progress (either layout)
  [[ -d "$(git rev-parse --git-path rebase-apply 2>/dev/null)" || -d "$(git rev-parse --git-path rebase-merge 2>/dev/null)" ]] \
    && op_warnings+=("rebase in progress (suggest: git rebase --abort)")

  # cherry-pick in progress
  [[ -f "$(git rev-parse --git-path CHERRY_PICK_HEAD 2>/dev/null)" ]] \
    && op_warnings+=("cherry-pick in progress (suggest: git cherry-pick --abort)")

  # revert in progress
  [[ -f "$(git rev-parse --git-path REVERT_HEAD 2>/dev/null)" ]] \
    && op_warnings+=("revert in progress (suggest: git revert --abort)")

  # bisect in progress (heuristic)
  [[ -f "$(git rev-parse --git-path BISECT_LOG 2>/dev/null)" ]] \
    && op_warnings+=("bisect in progress (suggest: git bisect reset)")

  if (( ${#op_warnings[@]} > 0 )); then
    print "🛡️  Detected an in-progress Git operation:"
    for w in "${op_warnings[@]}"; do
      print "   - $w"
    done
    print "⚠️  Resetting during these operations can be confusing."
    print -n "❓ Still run git-reset-undo (move HEAD back)? [y/N] "
    read -r confirm
    if [[ "$confirm" != [yY] ]]; then
      print "🚫 Aborted"
      return 1
    fi
  fi

  # ── Reflog display (with fallback for portability) ──────────────────────────
  # Preferred: direct HEAD@{n} form (most Git environments support this).
  reflog_line_current=$(git reflog -1 --pretty='%h %gs' HEAD@{0} 2>/dev/null)
  reflog_subject_current=$(git reflog -1 --pretty='%gs' HEAD@{0} 2>/dev/null)

  if [[ -z "$reflog_line_current" || -z "$reflog_subject_current" ]]; then
    # Fallback: reflog show latest entry for HEAD (informational only)
    reflog_line_current=$(git reflog show -1 --pretty='%h %gs' HEAD 2>/dev/null)
    reflog_subject_current=$(git reflog show -1 --pretty='%gs' HEAD 2>/dev/null)
  fi

  reflog_line_target=$(git reflog -1 --pretty='%h %gs' HEAD@{1} 2>/dev/null)
  reflog_subject_target=$(git reflog -1 --pretty='%gs' HEAD@{1} 2>/dev/null)

  if [[ -z "$reflog_line_target" || -z "$reflog_subject_target" ]]; then
    # Fallback: take the 2nd entry from reflog show -2 (informational only)
    reflog_line_target=$(git reflog show -2 --pretty='%h %gs' HEAD 2>/dev/null | sed -n '2p')
    reflog_subject_target=$(git reflog show -2 --pretty='%gs' HEAD 2>/dev/null | sed -n '2p')
  fi

  # If reflog lines are still unavailable, keep going (reflog display is informational).
  [[ -z "$reflog_line_current" ]] && reflog_line_current="(unavailable)"
  [[ -z "$reflog_line_target"  ]] && reflog_line_target="(unavailable)"
  [[ -z "$reflog_subject_current" ]] && reflog_subject_current="(unavailable)"
  [[ -z "$reflog_subject_target"  ]] && reflog_subject_target="(unavailable)"

  print "🧾 Current HEAD@{0} (last action):"
  print "   $reflog_line_current"
  print "🧾 Target  HEAD@{1} (previous HEAD position):"
  print "   $reflog_line_target"

  # If reflog display failed, clarify that the action is still deterministic via target_commit
  if [[ "$reflog_line_current" == "(unavailable)" || "$reflog_line_target" == "(unavailable)" ]]; then
    print "ℹ️  Reflog display unavailable here; reset target is still the resolved SHA: $target_commit"
  fi

  # Extra confirmation if the LAST action (HEAD@{0}) wasn't a reset.
  # (We still allow it—this tool can undo any HEAD move—but we make it explicit.)
  if [[ "$reflog_subject_current" != reset:* && "$reflog_subject_current" != "(unavailable)" ]]; then
    print "⚠️  The last action does NOT look like a reset operation."
    print "🧠 It may be from checkout/rebase/merge/pull, etc."
    print -n "❓ Still proceed to move HEAD back to the previous HEAD position? [y/N] "
    read -r confirm_non_reset
    if [[ "$confirm_non_reset" != [yY] ]]; then
      print "🚫 Aborted"
      return 1
    fi
  fi

  # Show the exact commit we are about to restore to (the stable SHA we resolved)
  print "🕰  Target commit (resolved from HEAD@{1}):"
  git log --oneline -1 "$target_commit" || return 1

  # Detect ANY local changes including untracked (default porcelain includes untracked)
  status_lines=$(git status --porcelain 2>/dev/null) || return 1

  # If there are no changes, safely hard reset without extra prompts
  if [[ -z "$status_lines" ]]; then
    print "✅ Working tree clean. Proceeding with: git reset --hard $target_commit"
    if ! git reset --hard "$target_commit"; then
      print "❌ Hard reset failed."
      return 1
    fi
    print "✅ Repository reset back to previous HEAD: $target_commit"
    return 0
  fi

  # If there are changes, warn and offer choices
  print "⚠️  Working tree has changes:"
  print -r -- "$status_lines"
  print ""
  print "Choose how to proceed:"
  print "  1) Keep changes + PRESERVE INDEX (staged vs new base)  (git reset --soft  $target_commit)"
  print "  2) Keep changes + UNSTAGE ALL                          (git reset --mixed $target_commit)"
  print "  3) Discard tracked changes                             (git reset --hard  $target_commit)"
  print "  4) Abort"
  print -n "❓ Select [1/2/3/4] (default: 4): "
  read -r choice

  case "$choice" in
    1)
      print "🧷 Preserving INDEX (staged) and working tree. Running: git reset --soft $target_commit"
      print "⚠️  Note: The index is preserved, but what appears staged is relative to the new HEAD."
      if ! git reset --soft "$target_commit"; then
        print "❌ Soft reset failed."
        return 1
      fi
      print "✅ HEAD moved back while preserving index + working tree: $target_commit"
      ;;

    2)
      print "🧷 Preserving working tree but clearing INDEX (unstage all). Running: git reset --mixed $target_commit"
      if ! git reset --mixed "$target_commit"; then
        print "❌ Mixed reset failed."
        return 1
      fi
      print "✅ HEAD moved back; working tree preserved; index reset: $target_commit"
      ;;

    3)
      print "🔥 Discarding tracked changes. Running: git reset --hard $target_commit"
      print "⚠️  This overwrites tracked files in working tree + index."
      print "ℹ️  Untracked files are NOT removed by reset --hard."
      print -n "❓ Are you absolutely sure? [y/N] "
      read -r confirm
      if [[ "$confirm" != [yY] ]]; then
        print "🚫 Aborted"
        return 1
      fi
      if ! git reset --hard "$target_commit"; then
        print "❌ Hard reset failed."
        return 1
      fi
      print "✅ Repository reset back to previous HEAD: $target_commit"
      ;;

    *)
      print "🚫 Aborted"
      return 1
      ;;
  esac

  return 0
}

# Rewind HEAD to its previous position with confirmation (using HEAD@{1})
#
# This function uses the reflog entry `HEAD@{1}` to move HEAD back to its
# previous position. It is useful when you have recently moved HEAD by mistake
# (e.g., via checkout, reset, commit, merge, rebase), and want to undo that movement.
#
# It shows the target commit before proceeding, so you can verify what you'll
# jump back to.
#
# ⚠️ Note:
# - This function uses `git checkout HEAD@{1}` and may update tracked files in
#   your working tree to match that previous state (or refuse if it would
#   overwrite local changes). It does NOT guarantee a no-touch working tree.
# - Depending on what `HEAD@{1}` points to, you may end up in a detached HEAD state.
git-back-head() {
  typeset prev_head

  # Resolve HEAD@{1} to a commit SHA for display/validation
  prev_head=$(git rev-parse HEAD@{1} 2>/dev/null)
  if [[ -z "$prev_head" ]]; then
    print "❌ Cannot find previous HEAD in reflog."
    return 1
  fi

  print "⏪ This will move HEAD back to the previous position (HEAD@{1}):"
  print "🔁 $(git log --oneline -1 "$prev_head")"
  print -n "❓ Proceed with 'git checkout HEAD@{1}'? [y/N] "
  read -r confirm
  if [[ "$confirm" != [yY] ]]; then
    print "🚫 Aborted"
    return 1
  fi

  # Move HEAD back using reflog syntax (requested)
  git checkout HEAD@{1}
  if [[ $? -ne 0 ]]; then
    print "❌ Checkout failed (likely due to local changes or invalid reflog state)."
    return 1
  fi

  print "✅ Restored to previous HEAD (HEAD@{1}): $prev_head"
}

# Restore HEAD to previous checkout branch (avoids detached HEAD)
#
# This function attempts to return to the branch you were on *before* you last
# checked out the current branch. It searches reflog for the most recent checkout
# entry that moved *to* the current branch, then extracts the "from" side.
#
# Safety improvements over the original version:
# - Handles detached HEAD (current branch == "HEAD") by aborting with a clear message.
# - Skips entries where the "from" token looks like a commit SHA (to avoid detached HEAD).
# - Verifies that the extracted "from" value is an existing local branch before checkout.
#
# Note: Checkout may fail if local changes would be overwritten.
git-back-checkout() {
  typeset current_branch from_branch

  # Determine the current branch; in detached HEAD this becomes literal "HEAD"
  current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || return 1
  if [[ -z "$current_branch" ]]; then
    print "❌ Cannot determine current branch."
    return 1
  fi

  # If we're detached, we can't reliably infer "previous branch" relative to a branch name
  if [[ "$current_branch" == "HEAD" ]]; then
    print "❌ You are in a detached HEAD state. This function targets branch-to-branch checkouts."
    print "🧠 Tip: Use `git reflog` to find the branch/commit you want, then `git checkout <branch>`."
    return 1
  fi

  # Find the most recent reflog checkout entry that moved *to* current_branch,
  # then extract the "from" token.
  from_branch=$(
    git reflog |
      grep "checkout: moving from " |
      grep " to $current_branch" |
      sed -n 's/.*checkout: moving from \([^ ]*\) to '"$current_branch"'.*/\1/p' |
      head -n 1
  )

  if [[ -z "$from_branch" ]]; then
    print "❌ Could not find a previous checkout that switched to $current_branch."
    return 1
  fi

  # Skip if the extracted token looks like a commit SHA (7-40 hex chars).
  # This avoids accidentally checking out a commit and entering detached HEAD.
  if [[ "$from_branch" == <-> ]]; then
    # purely numeric branch names are rare but possible; don't treat as SHA
    :
  elif [[ "$from_branch" == (#i)[0-9a-f]## && ${#from_branch} -ge 7 && ${#from_branch} -le 40 ]]; then
    print "❌ Previous 'from' looks like a commit SHA ($from_branch). Refusing to checkout to avoid detached HEAD."
    print "🧠 Use `git reflog` to choose the correct branch explicitly."
    return 1
  fi

  # Verify the branch exists locally before checking out
  if ! git show-ref --verify --quiet "refs/heads/$from_branch"; then
    print "❌ '$from_branch' is not an existing local branch."
    print "🧠 If it's a remote branch, try: git checkout -t origin/$from_branch"
    return 1
  fi

  print "⏪ This will move HEAD back to previous branch: $from_branch"
  print -n "❓ Proceed with 'git checkout $from_branch'? [y/N] "
  read -r confirm
  if [[ "$confirm" != [yY] ]]; then
    print "🚫 Aborted"
    return 1
  fi

  git checkout "$from_branch"
  if [[ $? -ne 0 ]]; then
    print "❌ Checkout failed (likely due to local changes or conflicts)."
    return 1
  fi

  print "✅ Restored to previous branch: $from_branch"
}

# Delete local branches that are already merged, with confirmation.
#
# This function lists local branches merged into a base ref (default: HEAD),
# then asks for confirmation before deleting them using `git branch -d`.
# With --squash, it also treats branches as deletable when all commits are
# already present in the base by patch-id (via `git cherry`).
# It protects the current branch, the base ref (and its local name if applicable),
# and common mainline branches (main/master/develop/trunk).
#
# Usage:
#   git-delete-merged-branches
#   git-delete-merged-branches -b main
#   git-delete-merged-branches --squash
git-delete-merged-branches() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset base_ref='HEAD'
  typeset base_local=''
  typeset confirm=''
  typeset current_branch=''
  typeset branch=''
  typeset name=''
  typeset base_commit=''
  typeset head_commit=''
  typeset delete_flag='-d'
  typeset squash_mode=false
  typeset cherry_output=''
  typeset branch_delete_flag=''
  typeset -a protected_branches=(main master develop trunk)
  typeset -a merged_branches=()
  typeset -a local_branches=()
  typeset -a candidates=()
  typeset -A protected_set=()
  typeset -A merged_set=()
  typeset -A opts=()

  if ! zmodload zsh/zutil 2>/dev/null; then
    print -u2 -r -- "❌ zsh/zutil module is required for option parsing"
    return 1
  fi
  zparseopts -D -E -A opts -- h -help b: -base: s -squash

  if (( ${+opts[-h]} || ${+opts[--help]} )); then
    print -r -- "Usage: git-delete-merged-branches [-b|--base <ref>] [-s|--squash]"
    print -r -- "  -b, --base <ref>  Base ref used to determine merged branches (default: HEAD)"
    print -r -- "  -s, --squash      Include branches already applied to base (git cherry)"
    return 0
  fi

  if (( ${+opts[-s]} || ${+opts[--squash]} )); then
    squash_mode=true
  fi

  if (( ${+opts[-b]} )); then
    base_ref="${opts[-b]}"
  elif (( ${+opts[--base]} )); then
    base_ref="${opts[--base]}"
  fi

  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    print -u2 -r -- "❌ Not in a git repository"
    return 1
  }

  git rev-parse --verify --quiet "$base_ref" >/dev/null || {
    print -u2 -r -- "❌ Invalid base ref: $base_ref"
    return 1
  }

  base_commit=$(git rev-parse "${base_ref}^{commit}" 2>/dev/null) || {
    print -u2 -r -- "❌ Unable to resolve base commit: $base_ref"
    return 1
  }
  head_commit=$(git rev-parse HEAD 2>/dev/null) || {
    print -u2 -r -- "❌ Unable to resolve HEAD commit"
    return 1
  }
  if [[ "$base_commit" != "$head_commit" ]]; then
    delete_flag='-D'
  fi

  current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || {
    print -u2 -r -- "❌ Unable to resolve current branch"
    return 1
  }

  for name in "${protected_branches[@]}"; do
    protected_set[$name]=1
  done
  if [[ -n "$current_branch" && "$current_branch" != 'HEAD' ]]; then
    protected_set[$current_branch]=1
  fi
  protected_set[$base_ref]=1
  if git show-ref --verify --quiet "refs/remotes/$base_ref"; then
    base_local="${base_ref#*/}"
  elif git show-ref --verify --quiet "refs/heads/$base_ref"; then
    base_local="$base_ref"
  fi
  if [[ -n "$base_local" ]]; then
    protected_set[$base_local]=1
  fi

  merged_branches=(${(@f)$(git for-each-ref --merged "$base_ref" --format='%(refname:short)' refs/heads)})
  for branch in "${merged_branches[@]}"; do
    merged_set[$branch]=1
  done

  if [[ "$squash_mode" != true ]]; then
    if (( ${#merged_branches[@]} == 0 )); then
      print -r -- "✅ No merged local branches found."
      return 0
    fi
  fi

  if [[ "$squash_mode" == true ]]; then
    local_branches=(${(@f)$(git for-each-ref --format='%(refname:short)' refs/heads)})
    if (( ${#local_branches[@]} == 0 )); then
      print -r -- "✅ No local branches found."
      return 0
    fi

    for branch in "${local_branches[@]}"; do
      if (( ${+protected_set[$branch]} )); then
        continue
      fi

      if (( ${+merged_set[$branch]} )); then
        candidates+=("$branch")
        continue
      fi

      cherry_output=$(git cherry -v "$base_ref" "$branch" 2>/dev/null) || {
        print -u2 -r -- "❌ Failed to compare $branch against $base_ref"
        return 1
      }

      if [[ -n "$cherry_output" ]] && printf '%s\n' "$cherry_output" | command grep -q '^\+'; then
        continue
      fi

      candidates+=("$branch")
    done
  else
    for branch in "${merged_branches[@]}"; do
      if (( ${+protected_set[$branch]} )); then
        continue
      fi
      candidates+=("$branch")
    done
  fi

  if (( ${#candidates[@]} == 0 )); then
    if [[ "$squash_mode" == true ]]; then
      print -r -- "✅ No deletable branches found."
    else
      print -r -- "✅ No deletable merged branches."
    fi
    return 0
  fi

  if [[ "$squash_mode" == true ]]; then
    print -r -- "🧹 Branches to delete (base: $base_ref, mode: squash):"
  else
    print -r -- "🧹 Merged branches to delete (base: $base_ref):"
  fi
  printf '  - %s\n' "${candidates[@]}"
  print -n -r -- "❓ Proceed with deleting these branches? [y/N] "
  read -r confirm
  if [[ "$confirm" != [yY] ]]; then
    print -r -- "🚫 Aborted"
    return 1
  fi

  for branch in "${candidates[@]}"; do
    branch_delete_flag="$delete_flag"
    if [[ "$delete_flag" == '-d' && "$squash_mode" == true ]] && (( ! ${+merged_set[$branch]} )); then
      branch_delete_flag='-D'
    fi
    git branch "$branch_delete_flag" -- "$branch"
  done

  print -r -- "✅ Deleted merged branches."
}

alias gdb='git-delete-merged-branches'
alias gdbs='gdb --squash'

# ────────────────────────────────────────────────────────
# GitHub / GitLab remote open helpers
# ────────────────────────────────────────────────────────

# git-resolve-upstream
# Resolve the remote/branch pair backing the current HEAD (prints remote then branch).
git-resolve-upstream() {
  emulate -L zsh
  setopt localoptions

  typeset fallback_remote='origin' branch='' upstream='' remote='' remote_branch=''

  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || {
    print -r -- "❌ Unable to resolve current branch" >&2
    return 1
  }

  upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)
  if [[ -n "$upstream" && "$upstream" != "$branch" ]]; then
    remote="${upstream%%/*}"
    remote_branch="${upstream#*/}"
  fi

  if [[ -z "$remote" ]]; then
    remote="$fallback_remote"
  fi

  if [[ -z "$remote_branch" || "$remote_branch" == "$upstream" || "$remote_branch" == 'HEAD' ]]; then
    remote_branch="$branch"
  fi

  print -r -- "$remote"
  print -r -- "$remote_branch"
}

# git-normalize-remote-url <remote>
# Convert a Git remote URL to an https form suitable for browsers and print it.
git-normalize-remote-url() {
  emulate -L zsh
  setopt localoptions

  typeset remote="$1"
  typeset raw_url='' normalized=''

  if [[ -z "$remote" ]]; then
    print -r -- "❌ git-normalize-remote-url requires remote name" >&2
    return 1
  fi

  raw_url=$(git remote get-url "$remote" 2>/dev/null) || {
    print -r -- "❌ Failed to resolve remote URL for $remote" >&2
    return 1
  }

  normalized=$(printf '%s\n' "$raw_url" | sed \
    -e 's/^git@/https:\/\//' \
    -e 's/com:/com\//' \
    -e 's/\.git$//' \
    -e 's/^ssh:\/\///' \
    -e 's/^https:\/\/git@/https:\/\//')

  if [[ -z "$normalized" ]]; then
    print -r -- "❌ Unable to normalize remote URL for $remote" >&2
    return 1
  fi

  print -r -- "$normalized"
}

# Open the repository page on GitHub or GitLab
gh-open() {
  emulate -L zsh
  setopt localoptions
  typeset -a upstream=()
  typeset remote='' remote_branch='' url=''

  upstream=(${(@f)$(git-resolve-upstream)}) || return 1
  if (( ${#upstream[@]} < 2 )); then
    print -r -- "❌ Failed to resolve upstream information" >&2
    return 1
  fi
  remote="${upstream[1]}"
  remote_branch="${upstream[2]}"

  url=$(git-normalize-remote-url "$remote") || return 1

  if command -v open &>/dev/null; then
    open "$url"
  elif command -v xdg-open &>/dev/null; then
    xdg-open "$url"
  else
    print -r -- "❌ Cannot open URL (no open/xdg-open)"
    return 1
  fi

  print -r -- "🌐 Opened: $url"
}

# Short aliases for common undo/reset operations
alias grs='git-reset-soft'
alias grm='git-reset-mixed'
alias grh='git-reset-hard'
alias gbh='git-back-head'
alias gbc='git-back-checkout'

# Open the current branch page on GitHub or GitLab
gh-open-branch() {
  emulate -L zsh
  setopt localoptions
  typeset -a upstream=()
  typeset remote='' remote_branch='' url='' target_url=''

  upstream=(${(@f)$(git-resolve-upstream)}) || return 1
  if (( ${#upstream[@]} < 2 )); then
    print -r -- "❌ Failed to resolve upstream information" >&2
    return 1
  fi
  remote="${upstream[1]}"
  remote_branch="${upstream[2]}"

  url=$(git-normalize-remote-url "$remote") || return 1

  target_url="$url/tree/$remote_branch"

  if command -v open &>/dev/null; then
    open "$target_url"
  elif command -v xdg-open &>/dev/null; then
    xdg-open "$target_url"
  else
    print -r -- "❌ Cannot open URL (no open/xdg-open)"
    return 1
  fi

  print -r -- "🌿 Opened: $target_url"
}

# Open a specific commit on GitHub (supports tag, branch, or commit hash)
gh-open-commit() {
  emulate -L zsh
  setopt localoptions
  typeset hash="${1:-HEAD}"
  typeset -a upstream=()
  typeset remote='' remote_branch='' url='' commit=''

  upstream=(${(@f)$(git-resolve-upstream)}) || return 1
  if (( ${#upstream[@]} < 2 )); then
    print -r -- "❌ Failed to resolve upstream information" >&2
    return 1
  fi
  remote="${upstream[1]}"
  remote_branch="${upstream[2]}"

  url=$(git-normalize-remote-url "$remote") || return 1

  if [[ "$url" != https://github.com/* ]]; then
    print -r -- "❗ Only GitHub URLs are supported."
    return 1
  fi

  # Ensure annotated tag resolves to commit, not tag object
  commit=$(git rev-parse "${hash}^{commit}" 2>/dev/null) || {
    print -r -- "❌ Invalid commit/tag/branch: $hash"
    return 1
  }

  typeset commit_url="$url/commit/$commit"
  print -r -- "🔗 Opening: $commit_url"

  if command -v open &>/dev/null; then
    open "$commit_url"
  elif command -v xdg-open &>/dev/null; then
    xdg-open "$commit_url"
  else
    print -r -- "❌ Cannot open URL (no open/xdg-open)"
    return 1
  fi
}

# Open default branch (main or master)
gh-open-default-branch() {
  emulate -L zsh
  setopt localoptions
  typeset -a upstream=()
  typeset remote='' remote_branch='' url='' default_branch=''

  upstream=(${(@f)$(git-resolve-upstream)}) || return 1
  if (( ${#upstream[@]} < 2 )); then
    print -r -- "❌ Failed to resolve upstream information" >&2
    return 1
  fi
  remote="${upstream[1]}"
  remote_branch="${upstream[2]}"

  url=$(git-normalize-remote-url "$remote") || return 1

  default_branch=$(git remote show "$remote" 2>/dev/null | awk '/HEAD branch/ {print $NF}')

  if [[ -z "$default_branch" ]]; then
    print -r -- "❌ Failed to resolve default branch for $remote"
    return 1
  fi

  typeset target_url="$url/tree/$default_branch"

  if command -v open &>/dev/null; then
    open "$target_url"
  elif command -v xdg-open &>/dev/null; then
    xdg-open "$target_url"
  else
    print -r -- "❌ Cannot open URL (no open/xdg-open)"
    return 1
  fi

  print -r -- "🌿 Opened: $target_url"
}

# Open the repository page on GitHub or GitLab
alias gop='gh-open'

# Open default branch
alias god='gh-open-default-branch'

# Open current HEAD commit
alias goc='gh-open-commit'

# Open current working branch
alias gob='gh-open-branch'

# Push current branch and open the pushed commit on GitHub or GitLab
gh-push-open() {
  git push "$@" || return $?
  gh-open-commit HEAD
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
  typeset -a extra_args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
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
        extra_args+=("$1")
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

alias gcc='git-commit-context'
