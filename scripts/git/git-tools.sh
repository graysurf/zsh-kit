# ────────────────────────────────────────────────────────
# Unalias to avoid redefinition
# ────────────────────────────────────────────────────────

unalias gr gpo greset-hard gu gum gdc groot \
        gh-open gh-open-branch \
        gh-open-commit gh-push-open \
        gundo gpick 2>/dev/null

# ────────────────────────────────────────────────────────
# Git operation aliases
# ────────────────────────────────────────────────────────

# Reset staged files (equivalent to "git reset")
alias gr='git reset'

# Push and open GitHub commit
alias gpo='gh-push-open'

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

# get_commit_hash <ref>
get_commit_hash() {
  local ref="$1"
  if [[ -z "$ref" ]]; then
    echo "❌ Missing git ref" >&2
    return 1
  fi

  # Try resolve commit (handles annotated tags too)
  git rev-parse --verify --quiet "${ref}^{commit}"
}

# ────────────────────────────────────────────────────────
# Git workflow helper functions
# ────────────────────────────────────────────────────────

# Soft reset last commit with confirmation
gu() {
  echo "⚠️  This will rewind your last commit (soft reset)"
  echo "🧠 Your changes will become UNSTAGED. Good for regrouping changes."
  echo -n "❓ Proceed with 'git reset --soft HEAD~1'? [y/N] "
  read -r confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "🚫 Aborted"
    return 1
  fi

  git reset --soft HEAD~1
  echo "✅ Last commit undone. Your changes are now unstaged & editable."
}

# Undo last commit but keep changes staged with confirmation
gum() {
  echo "⚠️  This will undo your last commit (soft reset)"
  echo "🧠 Your changes will remain STAGED. Useful for rewriting commit message."
  echo -n "❓ Proceed with 'git reset --soft HEAD~1'? [y/N] "
  read -r confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "🚫 Aborted"
    return 1
  fi

  git reset --soft HEAD~1
  echo "✅ Last commit undone. Your changes are still staged."
}

# FZF pick a commit and checkout to it
gpick() {
  git log --oneline --color=always |
    fzf --ansi --no-sort --reverse |
    cut -d ' ' -f 1 |
    xargs git checkout
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
