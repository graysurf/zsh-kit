# ────────────────────────────────────────────────────────
# Unalias to avoid redefinition
# ────────────────────────────────────────────────────────

unalias gr greset-hard guncommit gpushf gdc groot \
        ghopen ghbranch gundo gpick 2>/dev/null


# ────────────────────────────────────────────────────────
# Git operation aliases
# ────────────────────────────────────────────────────────

# Reset staged files (equivalent to "git reset")
alias gr='git reset'

# Full reset and clean untracked files — DANGER ZONE
alias greset-hard='git reset --hard && git clean -fd'

# Undo last commit but keep changes staged
alias guncommit='git reset --soft HEAD~1'

# Force push with lease (safer than --force)
alias gpushf='git push --force-with-lease'

# Copy staged diff to clipboard (no output)
gdc() {
  local diff
  diff=$(git diff --cached --no-color)

  if [[ -z "$diff" ]]; then
    echo "⚠️  No staged changes to copy"
    return 1
  fi

  printf "%s" "$diff" | pbcopy
  echo "✅ Staged diff copied to clipboard"
}

# Jump to the root directory of the current Git repository
groot() {
  local root
  root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "❌ Not in a git repository"
    return 1
  }
  cd "$root" && echo -e "\n 📁 Jumped to Git root: $root"
}

# ────────────────────────────────────────────────────────
# GitHub / GitLab remote open helpers
# ────────────────────────────────────────────────────────

# Open the repository page on GitHub or GitLab
gh-open() {
  local url
  url=$(git remote get-url origin 2>/dev/null | sed \
    -e 's/^git@/https:\/\//' \
    -e 's/com:/com\//' \
    -e 's/\.git$//' \
    -e 's/^ssh:\/\///' \
    -e 's/^https:\/\/git@/https:\/\//')

  if [[ -n "$url" ]]; then
    open "$url"
    echo "🌐 Opened: $url"
  else
    echo "❌ Unable to detect remote URL"
    return 1
  fi
}

# Open the current branch page on GitHub or GitLab
gh-open-branch() {
  local url branch
  url=$(git remote get-url origin 2>/dev/null | sed \
    -e 's/^git@/https:\/\//' \
    -e 's/com:/com\//' \
    -e 's/\.git$//' \
    -e 's/^ssh:\/\///' \
    -e 's/^https:\/\/git@/https:\/\//')
  branch=$(git rev-parse --abbrev-ref HEAD)

  if [[ -n "$url" && -n "$branch" ]]; then
    open "$url/tree/$branch"
    echo "🌿 Opened: $url/tree/$branch"
  else
    echo "❌ Failed to resolve URL or branch"
    return 1
  fi
}

# Open a specific commit on GitHub (supports tag, branch, or commit hash)
gh-open-commit() {
  local hash="${1:-HEAD}"
  local url commit

  url=$(git remote get-url origin 2>/dev/null) || {
    echo "❌ No remote 'origin' found"
    return 1
  }

  url=${url/git@github.com:/https:\/\/github.com\/}
  url=${url/https:\/\/git@github.com\//https:\/\/github.com\/}
  url=${url/.git/}

  if [[ "$url" != https://github.com/* ]]; then
    echo "❗ Only GitHub URLs are supported."
    return 1
  fi

  # Ensure annotated tag resolves to commit, not tag object
  commit=$(git rev-parse "${hash}^{commit}" 2>/dev/null) || {
    echo "❌ Invalid commit/tag/branch: $hash"
    return 1
  }

  local commit_url="$url/commit/$commit"
  echo "🔗 Opening: $commit_url"

  if command -v open &>/dev/null; then
    open "$commit_url"
  elif command -v xdg-open &>/dev/null; then
    xdg-open "$commit_url"
  else
    echo "❌ Cannot open URL (no open/xdg-open)"
    return 1
  fi
}

# Push current branch and open the pushed commit on GitHub or GitLab
gh-push-open() {
  git push "$@" || return $?
  gh-open-commit HEAD
}

# ────────────────────────────────────────────────────────
# Git workflow helper functions
# ────────────────────────────────────────────────────────

# Soft reset last commit with feedback
gundo() {
  echo "⚠️  This will rewind your last commit (soft reset)"
  read "confirm?❓ Proceed? [y/N] "
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "🚫 Aborted"
    return 1
  fi

  echo "🔁 Rewinding 1 commit (soft reset)..."
  git reset --soft HEAD~1
  echo "🌀 Your last commit is now unstaged & editable"
}


# FZF pick a commit and checkout to it
gpick() {
  git log --oneline --color=always |
    fzf --ansi --no-sort --reverse |
    cut -d ' ' -f 1 |
    xargs git checkout
}
