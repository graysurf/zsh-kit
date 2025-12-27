# ────────────────────────────────────────────────────────
# Git reset helpers
# ────────────────────────────────────────────────────────
if command -v safe_unalias >/dev/null; then
  safe_unalias \
    git-reset-soft \
    git-reset-hard \
    git-reset-mixed \
    git-reset-undo \
    git-back-head \
    git-back-checkout \
    git-reset-remote
fi

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

# Reset current branch to a remote-tracking ref (DANGEROUS)
git-reset-remote() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  zmodload zsh/zutil 2>/dev/null || {
    print -u2 -r -- "❌ zsh/zutil is required for zparseopts."
    return 1
  }

  typeset -A opts=()
  zparseopts -D -E -A opts -- \
    h -help \
    y -yes \
    r: -remote: \
    b: -branch: \
    -ref: \
    -no-fetch \
    -prune \
    -clean \
    -set-upstream || return 2

  if (( ${+opts[-h]} || ${+opts[--help]} )); then
    print -r -- "git-reset-remote: overwrite current local branch with a remote-tracking branch (DANGEROUS)"
    print -r --
    print -r -- "Usage:"
    print -r -- "  git-reset-remote  # reset current branch to its upstream (or origin/<branch>)"
    print -r -- "  git-reset-remote --ref origin/main"
    print -r -- "  git-reset-remote -r origin -b main"
    print -r --
    print -r -- "Options:"
    print -r -- "  -r, --remote <name>        Remote name (default: from upstream, else origin)"
    print -r -- "  -b, --branch <name>        Remote branch name (default: from upstream, else current branch)"
    print -r -- "      --ref <remote/branch>  Shortcut for --remote/--branch"
    print -r -- "      --no-fetch             Skip 'git fetch' (uses existing remote-tracking refs)"
    print -r -- "      --prune                Use 'git fetch --prune'"
    print -r -- "      --set-upstream         Set upstream of current branch to <remote>/<branch>"
    print -r -- "      --clean                After reset, optionally run 'git clean -fd' (removes untracked)"
    print -r -- "  -y, --yes                  Skip confirmations"
    return 0
  fi

  git rev-parse --git-dir >/dev/null 2>&1 || {
    print -u2 -r -- "❌ Not inside a Git repository."
    return 1
  }

  typeset current_branch=''
  current_branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null)" || {
    print -u2 -r -- "❌ Detached HEAD. Switch to a branch first."
    return 1
  }

  typeset upstream='' remote='' remote_branch='' ref=''
  upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"

  if [[ -n "${opts[--ref]-}" ]]; then
    ref="${opts[--ref]}"
    if [[ "$ref" != */* ]]; then
      print -u2 -r -- "❌ --ref must look like '<remote>/<branch>' (got: $ref)"
      return 2
    fi
    remote="${ref%%/*}"
    remote_branch="${ref#*/}"
  else
    remote="${opts[-r]-}"
    [[ -n "${opts[--remote]-}" ]] && remote="${opts[--remote]}"

    remote_branch="${opts[-b]-}"
    [[ -n "${opts[--branch]-}" ]] && remote_branch="${opts[--branch]}"

    if [[ -z "$remote" && -n "$upstream" && "$upstream" == */* ]]; then
      remote="${upstream%%/*}"
    fi
    [[ -z "$remote" ]] && remote='origin'

    if [[ -z "$remote_branch" ]]; then
      if [[ -n "$upstream" && "$upstream" == */* && "${upstream#*/}" != 'HEAD' ]]; then
        remote_branch="${upstream#*/}"
      else
        remote_branch="$current_branch"
      fi
    fi
  fi

  typeset target_ref="$remote/$remote_branch"
  typeset want_yes=0 want_clean=0 want_prune=0 want_fetch=1 want_set_upstream=0
  (( ${+opts[-y]} || ${+opts[--yes]} )) && want_yes=1
  (( ${+opts[--clean]} )) && want_clean=1
  (( ${+opts[--prune]} )) && want_prune=1
  (( ${+opts[--no-fetch]} )) && want_fetch=0
  (( ${+opts[--set-upstream]} )) && want_set_upstream=1

  if (( want_fetch )); then
    if (( want_prune )); then
      git fetch --prune -- "$remote" || return $?
    else
      git fetch -- "$remote" || return $?
    fi
  fi

  if ! git show-ref --verify --quiet "refs/remotes/$remote/$remote_branch"; then
    print -u2 -r -- "❌ Remote-tracking branch not found: $target_ref"
    print -u2 -r -- "   Try: git fetch --prune -- $remote"
    print -u2 -r -- "   Or verify: git branch -r | rg -n -- \"^\\s*$remote/$remote_branch$\""
    return 1
  fi

  typeset status_porcelain=''
  status_porcelain="$(git status --porcelain 2>/dev/null || true)"

  if (( !want_yes )); then
    print -r -- "⚠️  This will OVERWRITE local branch '$current_branch' with '$target_ref'."
    if [[ -n "$status_porcelain" ]]; then
      print -r -- "🔥 Tracked staged/unstaged changes will be DISCARDED by --hard."
      print -r -- "🧹 Untracked files will be kept (use --clean to remove)."
    fi
    print -n -- "❓ Proceed with: git reset --hard $target_ref ? [y/N] "
    typeset confirm=''
    read -r confirm
    if [[ "$confirm" != [yY] ]]; then
      print -r -- "🚫 Aborted"
      return 1
    fi
  fi

  git reset --hard "$target_ref" || return $?

  if (( want_clean )); then
    if (( !want_yes )); then
      print -r -- "⚠️  Next: git clean -fd (removes untracked files/dirs)"
      print -n -- "❓ Proceed with: git clean -fd ? [y/N] "
      typeset confirm_clean=''
      read -r confirm_clean
      if [[ "$confirm_clean" != [yY] ]]; then
        print -r -- "ℹ️  Skipped git clean -fd"
        want_clean=0
      fi
    fi
    if (( want_clean )); then
      git clean -fd || return $?
    fi
  fi

  if (( want_set_upstream || ${#upstream} == 0 )); then
    git branch --set-upstream-to="$target_ref" "$current_branch" >/dev/null 2>&1 || true
  fi

  print -r -- "✅ Done. '$current_branch' now matches '$target_ref'."
  return 0
}
