#!/bin/bash

# ────────────────────────────────────────────────────────
# Unalias to avoid redefinition
# ────────────────────────────────────────────────────────

unalias gr greset-hard guncommit gpushf gdc ghopen ghbranch glock gunlock gundo gpick gscope 2>/dev/null

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

# ────────────────────────────────────────────────────────
# GitHub / GitLab remote open helpers
# ────────────────────────────────────────────────────────

# Open the repository page on GitHub or GitLab
ghopen() {
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
ghbranch() {
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

# ────────────────────────────────────────────────────────
# Git workflow helper functions
# ────────────────────────────────────────────────────────

# Soft reset last commit with feedback
gundo() {
  echo "⚠️  Rewinding 1 commit (soft reset)..."
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

# Preview the structure of staged files using eza
gscope() {
  git diff --name-only --cached --diff-filter=ACMRTUXB |
    xargs eza -T --icons --color=always
}

# ────────────────────────────────────────────────────────
# Git lock / unlock helpers (manual commit fallback, repo-safe)
# ────────────────────────────────────────────────────────

# Save current commit hash for later restore, with optional note
glock() {
  local hash note repo_id lock_file
  hash=$(git rev-parse HEAD)
  note="$1"
  repo_id=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
  lock_file="$ZSH_CACHE_DIR/glock-${repo_id}.lock"

  if [[ -n "$note" ]]; then
    echo "$hash # $note" > "$lock_file"
    echo "🔐 [$repo_id] Locked: $hash  # $note"
  else
    echo "$hash" > "$lock_file"
    echo "🔐 [$repo_id] Locked: $hash"
  fi
}

# Reset to the locked commit hash, if present
gunlock() {
  local repo_id lock_file
  repo_id=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
  lock_file="$ZSH_CACHE_DIR/glock-${repo_id}.lock"

  if [[ ! -f "$lock_file" ]]; then
    echo "❌ No glock found for $repo_id"
    return 1
  fi

  local line hash note
  line=$(cat "$lock_file")
  hash=$(echo "$line" | cut -d '#' -f 1 | xargs)
  note=$(echo "$line" | cut -d '#' -f 2- | xargs)

  local msg
  msg=$(git log -1 --pretty=format:"%s" "$hash" 2>/dev/null)

  echo "🔐 Found glock for [$repo_id]:"
  echo "    → $hash"
  [[ -n "$note" ]] && echo "    # $note"
  [[ -n "$msg" ]] && echo "    commit message: $msg"
  echo

  # Allow `gunlock --force` to skip prompt
  if [[ "$1" != "--force" ]]; then
    read "confirm?⚠️  Are you sure you want to hard reset to this commit? [y/N] "
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
      echo "🚫 Aborted"
      return 1
    fi
  fi

  git reset --hard "$hash"
  echo "⏪ [$repo_id] Reset to: $hash${note:+  # $note}"
}

