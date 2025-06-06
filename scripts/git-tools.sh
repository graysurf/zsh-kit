#!/bin/bash

# ────────────────────────────────────────────────────────
# Unalias to avoid redefinition
# ────────────────────────────────────────────────────────

unalias gr greset-hard guncommit gpushf gdc ghopen ghbranch \
        glock gunlock gundo gpick gscope glock-list \
        glock-copy glock-delete 2>/dev/null

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

# Save the current commit hash into a named lock file
# - Allows optional label (default is "default")
# - Optional note can be recorded
# - A timestamp is stored for reference
# - The most recent glock label is saved to a "-latest" file
# - Lock files are stored under $ZSH_CACHE_DIR/glocks
#
# Example:
#   glock dev "before hotfix"
glock() {
  local hash label note repo_id lock_dir lock_file latest_file timestamp
  hash=$(git rev-parse HEAD)
  label="${1:-default}"
  note="$2"
  repo_id=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
  lock_dir="$ZSH_CACHE_DIR/glocks"
  lock_file="$lock_dir/${repo_id}-${label}.lock"
  latest_file="$lock_dir/${repo_id}-latest"
  timestamp=$(date "+%Y-%m-%d %H:%M:%S")

  [[ -d "$lock_dir" ]] || mkdir -p "$lock_dir"

  {
    echo "$hash # $note"
    echo "timestamp=$timestamp"
  } > "$lock_file"

  echo "$label" > "$latest_file"

  echo "🔐 [$repo_id:$label] Locked: $hash${note:+  # $note}"
  echo "    at $timestamp"
}

# Restore a previously saved commit hash by label (or the most recent one)
# - Prompts user before performing a hard reset
# - Retrieves note and original commit message for context
# - Aborts safely on missing label or user cancellation
#
# Example:
#   gunlock dev
gunlock() {
  local label repo_id lock_dir lock_file latest_file
  repo_id=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
  lock_dir="$ZSH_CACHE_DIR/glocks"
  latest_file="$lock_dir/${repo_id}-latest"

  [[ -d "$lock_dir" ]] || mkdir -p "$lock_dir"

  if [[ -n "$1" ]]; then
    label="$1"
  elif [[ -f "$latest_file" ]]; then
    label=$(cat "$latest_file")
  else
    echo "❌ No recent glock found for $repo_id"
    return 1
  fi

  lock_file="$lock_dir/${repo_id}-${label}.lock"
  if [[ ! -f "$lock_file" ]]; then
    echo "❌ No glock named '$label' found for $repo_id"
    return 1
  fi

  local line hash note msg
  line=$(cat "$lock_file")
  hash=$(echo "$line" | cut -d '#' -f 1 | xargs)
  note=$(echo "$line" | cut -d '#' -f 2- | xargs)
  msg=$(git log -1 --pretty=format:"%s" "$hash" 2>/dev/null)

  echo "🔐 Found [$repo_id:$label] → $hash"
  [[ -n "$note" ]] && echo "    # $note"
  [[ -n "$msg" ]] && echo "    commit message: $msg"
  echo

  read "confirm?⚠️  Hard reset to [$label]? [y/N] "
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "🚫 Aborted"
    return 1
  fi

  git reset --hard "$hash"
  echo "⏪ [$repo_id:$label] Reset to: $hash"
}

# Display a list of all saved glocks (labels) in the current repository
# - Includes commit hash, note, and timestamp for each label
# - Highlights the latest label with ⭐
#
# Example:
#   glock-list
glock-list() {
  local repo_id lock_dir lock_files
  repo_id=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
  lock_dir="$ZSH_CACHE_DIR/glocks"

  [[ -d "$lock_dir" ]] || {
    echo "📭 No glocks found for [$repo_id]"
    return 0
  }

  local latest
  if [[ -f "$lock_dir/${repo_id}-latest" ]]; then
    latest=$(cat "$lock_dir/${repo_id}-latest")
  fi

  lock_files=()
  for file in "$lock_dir/${repo_id}-"*.lock; do
    [[ -e "$file" && "$(basename "$file")" != "${repo_id}-latest.lock" ]] && lock_files+=("$file")
  done

  if [[ ${#lock_files[@]} -eq 0 ]]; then
    echo "📭 No glocks found for [$repo_id]"
    return 0
  fi

  echo "🔐 Glock list for [$repo_id]:"
  for file in "${lock_files[@]}"; do
    (
      local name content hash note timestamp
      name=$(basename "$file" .lock)
      label=${name#${repo_id}-}
      content=$(<"$file")
      hash=$(echo "$content" | sed -n '1p' | cut -d '#' -f1 | xargs)
      note=$(echo "$content" | sed -n '1p' | cut -d '#' -f2- | xargs)
      timestamp=$(echo "$content" | grep '^timestamp=' | cut -d '=' -f2-)

      printf "\n - 🏷️  tag:    %s%s\n" "$label" \
        "$( [[ "$label" == "$latest" ]] && echo '  ⭐ (latest)' )"
      printf "   🧬 commit: %s\n" "$hash"
      [[ -n "$note" ]] && printf "   📝 note:   %s\n" "$note"
      [[ -n "$timestamp" ]] && printf "   ⏰ time:   %s\n" "$timestamp"
    )
  done
}

# Copy an existing glock to a new label (preserving all metadata)
# - Copies both hash and note content as-is to a new lock file
# - Prompts before overwrite if the target already exists
# - Sets the copied label as latest
#
# Example:
#   glock-copy dev staging
glock-copy() {
  local src_label dst_label repo_id lock_dir src_file dst_file
  repo_id=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
  lock_dir="$ZSH_CACHE_DIR/glocks"

  [[ -d "$lock_dir" ]] || {
    echo "❌ No glocks found"
    return 1
  }

  if [[ -z "$1" || -z "$2" ]]; then
    echo "❗ Usage: glock-copy <source-label> <target-label>"
    return 1
  fi

  src_label="$1"
  dst_label="$2"
  src_file="$lock_dir/${repo_id}-${src_label}.lock"
  dst_file="$lock_dir/${repo_id}-${dst_label}.lock"

  if [[ ! -f "$src_file" ]]; then
    echo "❌ Source glock [$repo_id:$src_label] not found"
    return 1
  fi

  if [[ -f "$dst_file" ]]; then
    echo "⚠️  Target glock [$repo_id:$dst_label] already exists"
    read "confirm?❓ Overwrite it? [y/N] "
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
      echo "🚫 Aborted"
      return 1
    fi
  fi

  cp "$src_file" "$dst_file"
  echo "$dst_label" > "$lock_dir/${repo_id}-latest"

  echo "📋 Copied glock [$repo_id:$src_label] → [$repo_id:$dst_label]"
  echo "   🏷️  $src_label → $dst_label"
}

# Delete a glock by label or the most recent one
# - Displays details of the glock before deletion (hash, note, timestamp)
# - Prompts for confirmation before deletion
# - Removes latest marker if the deleted one was the latest
#
# Example:
#   glock-delete dev
glock-delete() {
  local label repo_id lock_dir lock_file latest_file
  repo_id=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
  lock_dir="$ZSH_CACHE_DIR/glocks"
  latest_file="$lock_dir/${repo_id}-latest"

  [[ -d "$lock_dir" ]] || {
    echo "❌ No glocks found"
    return 1
  }

  if [[ -n "$1" ]]; then
    label="$1"
  elif [[ -f "$latest_file" ]]; then
    label=$(cat "$latest_file")
  else
    echo "❌ No label provided and no latest glock exists"
    return 1
  fi

  lock_file="$lock_dir/${repo_id}-${label}.lock"
  if [[ ! -f "$lock_file" ]]; then
    echo "❌ Glock [$label] not found"
    return 1
  fi

  local content hash note timestamp
  content=$(<"$lock_file")
  hash=$(echo "$content" | sed -n '1p' | cut -d '#' -f1 | xargs)
  note=$(echo "$content" | sed -n '1p' | cut -d '#' -f2- | xargs)
  timestamp=$(echo "$content" | grep '^timestamp=' | cut -d '=' -f2-)

  echo "🗑️  Candidate for deletion:"
  printf "   🏷️  tag:    %s\n" "$label"
  printf "   🧬 commit: %s\n" "$hash"
  [[ -n "$note" ]] && printf "   📝 note:   %s\n" "$note"
  [[ -n "$timestamp" ]] && printf "   ⏰ time:   %s\n" "$timestamp"
  echo

  read "confirm?⚠️  Delete this glock? [y/N] "
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "🚫 Aborted"
    return 1
  fi

  rm -f "$lock_file"
  echo "🗑️  Deleted glock [$repo_id:$label]"

  if [[ -f "$latest_file" && "$(cat "$latest_file")" == "$label" ]]; then
    rm -f "$latest_file"
    echo "🧼 Removed latest marker (was [$label])"
  fi
}

# Compare two glocks by label and show their commit diff (log)
#
# Usage:
#   glock-diff <label1> <label2>
#
# This will show the commits between the two glock points using: git log <hash1>..<hash2>
glock-diff() {
  local label1 label2 repo_id lock_dir file1 file2 hash1 hash2

  if [[ -z "$1" || -z "$2" ]]; then
    echo "❗ Usage: glock-diff <label1> <label2>"
    return 1
  fi

  label1="$1"
  label2="$2"
  repo_id=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
  lock_dir="$ZSH_CACHE_DIR/glocks"
  file1="$lock_dir/${repo_id}-${label1}.lock"
  file2="$lock_dir/${repo_id}-${label2}.lock"

  if [[ ! -f "$file1" ]]; then
    echo "❌ Glock [$label1] not found for [$repo_id]"
    return 1
  fi
  if [[ ! -f "$file2" ]]; then
    echo "❌ Glock [$label2] not found for [$repo_id]"
    return 1
  fi

  hash1=$(sed -n '1p' "$file1" | cut -d '#' -f1 | xargs)
  hash2=$(sed -n '1p' "$file2" | cut -d '#' -f1 | xargs)

  echo "🧮 Comparing commits: [$repo_id:$label1] → [$label2]"
  echo "   🔖 $label1: $hash1"
  echo "   🔖 $label2: $hash2"
  echo

  git log --oneline --graph --decorate "$hash1..$hash2"
}