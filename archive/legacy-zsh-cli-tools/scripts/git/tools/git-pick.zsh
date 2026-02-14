# ────────────────────────────────────────────────────────
# Git CI branch helper
# ────────────────────────────────────────────────────────
if command -v safe_unalias >/dev/null; then
  safe_unalias git-pick
fi

# _git_pick_usage
# Print usage for git-pick.
# Usage: _git_pick_usage
_git_pick_usage() {
  emulate -L zsh
  setopt err_return nounset

  print -r -- "git-pick: create and push a CI branch with cherry-picked commits"
  print -r --
  print -r -- "Usage:"
  print -r -- "  git-pick <target> <commit-or-range> <name>"
  print -r --
  print -r -- "Args:"
  print -r -- "  <target>           Base branch/ref (e.g. main, release/x, origin/main)"
  print -r -- "  <commit-or-range>  Passed to 'git cherry-pick' (e.g. abc123, A..B, A^..B)"
  print -r -- "  <name>             Suffix for CI branch: ci/<target>/<name>"
  print -r --
  print -r -- "Options:"
  print -r -- "  -r, --remote <name>  Remote to fetch/push (default: origin, else first remote)"
  print -r -- "      --no-fetch       Skip 'git fetch' (uses existing local refs)"
  print -r -- "  -f, --force          Reset existing ci/<target>/<name> and force-push (with lease)"
  print -r -- "      --stay           Keep checked out on the CI branch"
  return 0
}

# git-pick [options] <target> <commit-or-range> <name>
# Create a CI branch based on <target>, cherry-pick <commit-or-range>, then push.
# Usage: git-pick <target> <commit-or-range> <name>
# Notes:
# - CI branch name: ci/<target>/<name> (if <target> is <remote>/<branch>, uses <branch>).
# - Intended for "test this subset of commits on target CI" without merging the PR.
git-pick() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  zmodload zsh/zutil 2>/dev/null || {
    print -u2 -r -- "❌ zsh/zutil is required for zparseopts."
    return 1
  }

  typeset -A opts=()
  zparseopts -D -E -A opts -- \
    h -help \
    r: -remote: \
    f -force \
    -no-fetch \
    -stay || return 2

  if (( ${+opts[-h]} || ${+opts[--help]} )); then
    _git_pick_usage
    return 0
  fi

  typeset target="${1-}"
  typeset commit_spec="${2-}"
  typeset name="${3-}"
  typeset extra="${4-}"

  if [[ -z "$target" || -z "$commit_spec" || -z "$name" || -n "$extra" ]]; then
    print -u2 -r -- "❌ Usage: git-pick <target> <commit-or-range> <name>"
    print -u2 -r -- "   Try: git-pick --help"
    return 2
  fi

  git rev-parse --git-dir >/dev/null 2>&1 || {
    print -u2 -r -- "❌ Not inside a Git repository."
    return 1
  }

  # Avoid surprising state changes during in-progress Git operations.
  typeset -a op_warnings=()
  [[ -f "$(git rev-parse --git-path MERGE_HEAD 2>/dev/null)" ]] && op_warnings+=("merge in progress")
  [[ -d "$(git rev-parse --git-path rebase-apply 2>/dev/null)" || -d "$(git rev-parse --git-path rebase-merge 2>/dev/null)" ]] && op_warnings+=("rebase in progress")
  [[ -f "$(git rev-parse --git-path CHERRY_PICK_HEAD 2>/dev/null)" ]] && op_warnings+=("cherry-pick in progress")
  [[ -f "$(git rev-parse --git-path REVERT_HEAD 2>/dev/null)" ]] && op_warnings+=("revert in progress")
  if (( ${#op_warnings[@]} > 0 )); then
    print -u2 -r -- "❌ Refusing to run during an in-progress Git operation:"
    typeset w=''
    for w in "${op_warnings[@]}"; do
      print -u2 -r -- "   - $w"
    done
    return 1
  fi

  # Require a clean index + working tree (allow untracked files).
  if ! git diff --quiet --no-ext-diff; then
    print -u2 -r -- "❌ Unstaged changes detected. Commit or stash before running git-pick."
    return 1
  fi
  if ! git diff --cached --quiet --no-ext-diff; then
    print -u2 -r -- "❌ Staged changes detected. Commit or stash before running git-pick."
    return 1
  fi

  typeset -a remotes=()
  remotes=(${(f)"$(git remote 2>/dev/null || true)"})
  if (( ${#remotes[@]} == 0 )); then
    print -u2 -r -- "❌ No git remotes found (need a remote to push CI branches)."
    return 1
  fi

  typeset remote_opt=''
  remote_opt="${opts[-r]-}"
  [[ -n "${opts[--remote]-}" ]] && remote_opt="${opts[--remote]}"

  typeset remote="$remote_opt"
  if [[ -z "$remote" ]]; then
    if (( ${remotes[(I)origin]} )); then
      remote='origin'
    else
      remote="${remotes[1]}"
    fi
  fi

  typeset target_remote=''
  typeset target_branch="$target"
  typeset target_branch_for_name="$target"

  # If <target> looks like <remote>/<branch>, treat it as a remote ref.
  if [[ "$target" == */* ]]; then
    typeset maybe_remote="${target%%/*}"
    if (( ${remotes[(I)$maybe_remote]} )); then
      target_remote="$maybe_remote"
      target_branch="${target#*/}"
      target_branch_for_name="$target_branch"
      if [[ -z "$remote_opt" ]]; then
        remote="$target_remote"
      elif [[ "$remote" != "$target_remote" ]]; then
        print -u2 -r -- "❌ Target ref looks like '$target' (remote '$target_remote') but --remote is '$remote'."
        return 2
      fi
    fi
  fi

  typeset want_force=0 want_fetch=1 want_stay=0
  (( ${+opts[-f]} || ${+opts[--force]} )) && want_force=1
  (( ${+opts[--no-fetch]} )) && want_fetch=0
  (( ${+opts[--stay]} )) && want_stay=1

  if (( want_fetch )); then
    # Best-effort: keep the base branch current.
    if ! git fetch --prune -- "$remote" "$target_branch" >/dev/null 2>&1; then
      print -u2 -r -- "⚠️  Fetch failed: git fetch --prune -- $remote $target_branch"
      print -u2 -r -- "   Continuing with local refs (or re-run with --no-fetch)."
    fi
  fi

  typeset base_ref=''
  if git show-ref --verify --quiet "refs/remotes/$remote/$target_branch"; then
    base_ref="$remote/$target_branch"
  elif git show-ref --verify --quiet "refs/heads/$target_branch"; then
    base_ref="$target_branch"
  elif git rev-parse --verify --quiet "${target}^{commit}" >/dev/null 2>&1; then
    base_ref="$target"
  else
    print -u2 -r -- "❌ Cannot resolve target ref: $target"
    return 1
  fi

  typeset ci_branch="ci/$target_branch_for_name/$name"
  if ! git check-ref-format --branch "$ci_branch" >/dev/null 2>&1; then
    print -u2 -r -- "❌ Invalid CI branch name: $ci_branch"
    return 2
  fi

  # Resolve commits to pick BEFORE switching branches (so relative refs like HEAD~2 work).
  typeset -a pick_commits=()
  if [[ "$commit_spec" == *..* ]]; then
    pick_commits=(${(f)"$(git rev-list --reverse "$commit_spec" 2>/dev/null || true)"})
    if (( ${#pick_commits[@]} == 0 )); then
      print -u2 -r -- "❌ No commits resolved from range: $commit_spec"
      return 1
    fi
  else
    typeset commit_sha=''
    commit_sha="$(git rev-parse --verify "${commit_spec}^{commit}" 2>/dev/null || true)"
    if [[ -z "$commit_sha" ]]; then
      print -u2 -r -- "❌ Cannot resolve commit: $commit_spec"
      return 1
    fi
    pick_commits=("$commit_sha")
  fi

  # Record current position for convenience; we only switch back on success.
  typeset orig_branch='' orig_sha=''
  orig_branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
  orig_sha="$(git rev-parse --verify HEAD 2>/dev/null || true)"

  if git show-ref --verify --quiet "refs/heads/$ci_branch"; then
    if (( !want_force )); then
      print -u2 -r -- "❌ Local branch already exists: $ci_branch"
      print -u2 -r -- "   Use --force to reset/rebuild it."
      return 1
    fi
  fi
  if (( !want_force )) && ! git show-ref --verify --quiet "refs/heads/$ci_branch"; then
    typeset remote_ci_ref=''
    remote_ci_ref="$(git ls-remote --heads "$remote" "$ci_branch" 2>/dev/null || true)"
    if [[ -n "$remote_ci_ref" ]]; then
      print -u2 -r -- "❌ Remote branch already exists: $remote/$ci_branch"
      print -u2 -r -- "   Use --force to reset/rebuild it."
      return 1
    fi
  fi

  print -r -- "🌿 CI branch: $ci_branch"
  print -r -- "🔧 Base     : $base_ref"
  print -r -- "🍒 Pick     : $commit_spec (${#pick_commits[@]} commit(s))"

  if git show-ref --verify --quiet "refs/heads/$ci_branch"; then
    git switch --quiet -- "$ci_branch" || return $?
    git reset --hard "$base_ref" || return $?
  else
    git switch --quiet -c "$ci_branch" "$base_ref" || return $?
  fi

  if ! git cherry-pick -- "${pick_commits[@]}"; then
    print -u2 -r -- "❌ Cherry-pick failed on branch: $ci_branch"
    print -u2 -r -- "🧠 Resolve conflicts then run: git cherry-pick --continue"
    print -u2 -r -- "    Or abort and retry:        git cherry-pick --abort"
    return 1
  fi

  if (( want_force )); then
    git push -u --force-with-lease -- "$remote" "$ci_branch" || return $?
  else
    git push -u -- "$remote" "$ci_branch" || return $?
  fi

  print -r -- "✅ Pushed: $remote/$ci_branch (CI should run on branch push)"
  print -r -- "🧹 Cleanup:"
  print -r -- "  git push --delete -- $remote $ci_branch"
  print -r -- "  git branch -D -- $ci_branch"

  if (( want_stay )); then
    return 0
  fi

  if [[ -n "$orig_branch" ]]; then
    git switch --quiet -- "$orig_branch" || true
  elif [[ -n "$orig_sha" ]]; then
    git switch --quiet --detach "$orig_sha" || true
  fi

  return 0
}
