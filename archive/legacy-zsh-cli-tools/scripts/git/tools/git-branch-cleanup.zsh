# ────────────────────────────────────────────────────────
# Git branch cleanup helpers
# ────────────────────────────────────────────────────────
if command -v safe_unalias >/dev/null; then
  safe_unalias git-delete-merged-branches
fi

# git-delete-merged-branches [-b|--base <ref>] [-s|--squash]
# Delete merged local branches with confirmation.
# Usage: git-delete-merged-branches [-b|--base <ref>] [-s|--squash]
# Notes:
# - Protects current branch, base ref, and main/master/develop/trunk.
# - With `--squash`, treats branches as deletable when their commits are already applied (git cherry).
# Safety:
# - Deleting local branches is irreversible unless you still have the commit SHA (reflog may help).
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

      if [[ -n "$cherry_output" ]] && printf '%s\n' "$cherry_output" | command grep -q '^[+]'; then
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
