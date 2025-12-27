# ────────────────────────────────────────────────────────
# Git remote open helpers
# ────────────────────────────────────────────────────────
if command -v safe_unalias >/dev/null; then
  safe_unalias \
    git-resolve-upstream \
    git-normalize-remote-url \
    git-open \
    git-open-branch \
    git-open-default-branch \
    git-open-commit \
    gh-push-open
fi

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
git-open() {
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

# Open the current branch page on GitHub or GitLab
git-open-branch() {
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
git-open-commit() {
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
git-open-default-branch() {
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

# Push current branch and open the pushed commit on GitHub or GitLab
gh-push-open() {
  git push "$@" || return $?
  git-open-commit HEAD
}
