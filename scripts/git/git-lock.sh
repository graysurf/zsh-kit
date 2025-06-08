# ────────────────────────────────────────────────────────
# Git lock / unlock helpers (manual commit fallback, repo-safe)
# ────────────────────────────────────────────────────────

# Resolve label from argument or latest fallback
_git_lock_resolve_label() {
  local input_label="$1"
  local repo_id lock_dir latest_file

  repo_id=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
  lock_dir="$ZSH_CACHE_DIR/git-locks"
  [[ -d "$lock_dir" ]] || mkdir -p "$lock_dir"
  latest_file="$lock_dir/${repo_id}-latest"

  if [[ -n "$input_label" ]]; then
    echo "$input_label"
  elif [[ -f "$latest_file" ]]; then
    cat "$latest_file"
  else
    return 1
  fi
}

# Save the current commit hash into a named lock file
# - Allows optional label (default is "default")
# - Optional note can be recorded
# - Optional commit hash can be specified (default is HEAD)
# - A timestamp is stored for reference
# - The most recent git-lock label is saved to a "-latest" file
# - Lock files are stored under $ZSH_CACHE_DIR/git-locks
#
# Example:
#   git-lock dev "before hotfix"
#   git-lock hotfix "old code" HEAD~2
#   git-lock release "tag version" v1.0.0
_git_lock() {
  local label note commit repo_id lock_dir lock_file latest_file timestamp hash

  label="${1:-default}"
  note="$2"
  commit="${3:-HEAD}"

  repo_id=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
  lock_dir="$ZSH_CACHE_DIR/git-locks"
  lock_file="$lock_dir/${repo_id}-${label}.lock"
  latest_file="$lock_dir/${repo_id}-latest"
  timestamp=$(date "+%Y-%m-%d %H:%M:%S")

  hash=$(git rev-parse "$commit" 2>/dev/null) || {
    echo "❌ Invalid commit: $commit"
    return 1
  }

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
_git_lock_unlock() {
  local repo_id lock_dir label lock_file latest_label
  repo_id=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
  lock_dir="$ZSH_CACHE_DIR/git-locks"

  [[ -d "$lock_dir" ]] || mkdir -p "$lock_dir"

  label=$(_git_lock_resolve_label "$1") || {
    echo "❌ No recent git-lock found for $repo_id"
    return 1
  }

  lock_file="$lock_dir/${repo_id}-${label}.lock"
  if [[ ! -f "$lock_file" ]]; then
    echo "❌ No git-lock named '$label' found for $repo_id"
    return 1
  fi

  local line hash note msg
  read -r line < "$lock_file"
  hash=$(echo "$line" | cut -d '#' -f 1 | xargs)
  note=$(echo "$line" | cut -d '#' -f 2- | xargs)
  msg=$(git log -1 --pretty=format:"%s" "$hash" 2>/dev/null)

  echo "🔐 Found [$repo_id:$label] → $hash"
  [[ -n "$note" ]] && echo "    # $note"
  [[ -n "$msg" ]] && echo "    commit message: $msg"
  echo

  read -r -p "⚠️  Hard reset to [$label]? [y/N] " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "🚫 Aborted"
    return 1
  fi

  git reset --hard "$hash"
  echo "⏪ [$repo_id:$label] Reset to: $hash"
}


# Display a list of all saved git-locks (labels) in the current repository
# - Includes commit hash, note, timestamp, and commit subject
# - Highlights the latest label with ⭐
#
# Example:
#   git-lock-list
_git_lock() {
  local label note commit repo_id lock_dir lock_file latest_file timestamp hash

  label="${1:-default}"
  note="$2"
  commit="${3:-HEAD}"

  repo_id=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
  lock_dir="$ZSH_CACHE_DIR/git-locks"
  lock_file="$lock_dir/${repo_id}-${label}.lock"
  latest_file="$lock_dir/${repo_id}-latest"
  timestamp=$(date "+%Y-%m-%d %H:%M:%S")

  hash=$(git rev-parse "$commit" 2>/dev/null) || {
    echo "❌ Invalid commit: $commit"
    return 1
  }

  [[ -d "$lock_dir" ]] || mkdir -p "$lock_dir"

  {
    echo "$hash # $note"
    echo "timestamp=$timestamp"
  } > "$lock_file"

  echo "$label" > "$latest_file"

  echo "🔐 [$repo_id:$label] Locked: $hash${note:+  # $note}"
  echo "    at $timestamp"
}

_git_lock_unlock() {
  local label repo_id lock_dir lock_file latest_file
  repo_id=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
  lock_dir="$ZSH_CACHE_DIR/git-locks"
  latest_file="$lock_dir/${repo_id}-latest"

  [[ -d "$lock_dir" ]] || mkdir -p "$lock_dir"

  if [[ -n "$1" ]]; then
    label="$1"
  elif [[ -f "$latest_file" ]]; then
    label=$(cat "$latest_file")
  else
    echo "❌ No recent git-lock found for $repo_id"
    return 1
  fi

  lock_file="$lock_dir/${repo_id}-${label}.lock"
  if [[ ! -f "$lock_file" ]]; then
    echo "❌ No git-lock named '$label' found for $repo_id"
    return 1
  fi

  local hash note msg
  read -r line < "$lock_file"
  hash=$(echo "$line" | cut -d '#' -f 1 | xargs)
  note=$(echo "$line" | cut -d '#' -f 2- | xargs)
  msg=$(git log -1 --pretty=format:"%s" "$hash" 2>/dev/null)

  echo "🔐 Found [$repo_id:$label] → $hash"
  [[ -n "$note" ]] && echo "    # $note"
  [[ -n "$msg" ]] && echo "    commit message: $msg"
  echo

  read -r -p "⚠️  Hard reset to [$label]? [y/N] " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "🚫 Aborted"
    return 1
  fi

  git reset --hard "$hash"
  echo "⏪ [$repo_id:$label] Reset to: $hash"
}

_git_lock_list() {
  local repo_id lock_dir latest
  repo_id=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
  lock_dir="$ZSH_CACHE_DIR/git-locks"

  [[ -d "$lock_dir" ]] || {
    echo "📬 No git-locks found for [$repo_id]"
    return 0
  }

  [[ -f "$lock_dir/${repo_id}-latest" ]] && latest=$(<"$lock_dir/${repo_id}-latest")

  # Test without for loop, just declare local variables
  local tag hash note timestamp subject

  # Check the local variables
  echo "🔐 [TEST] git-lock list for [$repo_id]:"
  echo "tag: $tag"
  echo "hash: $hash"
  echo "note: $note"
  echo "timestamp: $timestamp"
  echo "subject: $subject"
}

_git_lock_list() {
  local repo_id lock_dir latest
  repo_id=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
  lock_dir="$ZSH_CACHE_DIR/git-locks"

  [[ -d "$lock_dir" ]] || {
    echo "📬 No git-locks found for [$repo_id]"
    return 0
  }

  [[ -f "$lock_dir/${repo_id}-latest" ]] && latest=$(cat "$lock_dir/${repo_id}-latest")

  local file tmp_list=()
  for file in "$lock_dir/${repo_id}-"*.lock; do
    [[ -e "$file" && "$(basename "$file")" != "${repo_id}-latest.lock" ]] || continue
    local ts_line='' epoch=''
    ts_line=$(grep '^timestamp=' "$file")
    timestamp=${ts_line#timestamp=}
    epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "$timestamp" "+%s" 2>/dev/null || date -d "$timestamp" "+%s")
    tmp_list+=("$epoch|$file")
  done

  IFS=$'\n' sorted=($(printf '%s\n' "${tmp_list[@]}" | sort -rn))

  if [[ ${#sorted[@]} -eq 0 ]]; then
    echo "📬 No git-locks found for [$repo_id]"
    return 0
  fi

  echo "🔐 git-lock list for [$repo_id]:"
  for item in "${sorted[@]}"; do
    file="${item#*|}"
    local name='' hash='' note='' timestamp='' label='' subject='' line=''
    name=$(basename "$file" .lock)
    label=${name#${repo_id}-}
    read -r line < "$file"
    hash=$(echo "$line" | cut -d '#' -f1 | xargs)
    note=$(echo "$line" | cut -d '#' -f2- | xargs)
    timestamp=$(grep '^timestamp=' "$file" | cut -d '=' -f2-)
    subject=$(git log -1 --pretty=%s "$hash" 2>/dev/null)

    printf "\n - 🏷️  tag:     %s%s\n" "$label" \
      "$( [[ "$label" == "$latest" ]] && echo '  ⭐ (latest)' )"
    printf "   🧬 commit:  %s\n" "$hash"
    [[ -n "$subject" ]] && printf "   📄 message: %s\n" "$subject"
    [[ -n "$note" ]] && printf "   📝 note:    %s\n" "$note"
    [[ -n "$timestamp" ]] && printf "   📅 time:    %s\n" "$timestamp"
  done
}

# Copy an existing git-lock to a new label (preserving all metadata)
# - Copies both hash and note content as-is to a new lock file
# - Prompts before overwrite if the target already exists
# - Sets the copied label as latest
#
# Example:
#   git-lock-copy dev staging
_git_lock_copy() {
  local repo_id lock_dir src_label dst_label src_file dst_file
  repo_id=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
  lock_dir="$ZSH_CACHE_DIR/git-locks"

  [[ -d "$lock_dir" ]] || {
    echo "❌ No git-locks found"
    return 1
  }

  src_label=$(_git_lock_resolve_label "$1") || {
    echo "❗ Usage: git-lock-copy <source-label> <target-label>"
    return 1
  }
  dst_label="$2"
  [[ -z "$dst_label" ]] && {
    echo "❗ Target label is missing"
    return 1
  }

  src_file="$lock_dir/${repo_id}-${src_label}.lock"
  dst_file="$lock_dir/${repo_id}-${dst_label}.lock"

  if [[ ! -f "$src_file" ]]; then
    echo "❌ Source git-lock [$repo_id:$src_label] not found"
    return 1
  fi

  if [[ -f "$dst_file" ]]; then
    read "confirm?⚠️  Target git-lock [$repo_id:$dst_label] already exists. Overwrite? [y/N] "
    [[ "$confirm" != [yY] ]] && {
      echo "🚫 Aborted"
      return 1
    }
  fi

  cp "$src_file" "$dst_file"
  echo "$dst_label" > "$lock_dir/${repo_id}-latest"

  local content hash note timestamp subject
  content=$(<"$src_file")
  hash=$(echo "$content" | sed -n '1p' | cut -d '#' -f1 | xargs)
  note=$(echo "$content" | sed -n '1p' | cut -d '#' -f2- | xargs)
  timestamp=$(echo "$content" | grep '^timestamp=' | cut -d '=' -f2-)
  subject=$(git log -1 --pretty=%s "$hash" 2>/dev/null)

  echo "📋 Copied git-lock [$repo_id:$src_label] → [$repo_id:$dst_label]"
  printf "   🏷️  tag:     %s → %s\n" "$src_label" "$dst_label"
  printf "   🧬 commit:  %s\n" "$hash"
  [[ -n "$subject" ]] && printf "   📄 message: %s\n" "$subject"
  [[ -n "$note" ]] && printf "   📝 note:    %s\n" "$note"
  [[ -n "$timestamp" ]] && printf "   📅 time:    %s\n" "$timestamp"
}


# Delete a git-lock by label or the most recent one
# - Displays details of the git-lock before deletion (hash, note, timestamp)
# - Prompts for confirmation before deletion
# - Removes latest marker if the deleted one was the latest
#
# Example:
#   git-lock-delete dev
_git_lock_delete() {
  local repo_id lock_dir label lock_file latest_file latest_label
  repo_id=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
  lock_dir="$ZSH_CACHE_DIR/git-locks"
  latest_file="$lock_dir/${repo_id}-latest"

  [[ -d "$lock_dir" ]] || {
    echo "❌ No git-locks found"
    return 1
  }

  label=$(_git_lock_resolve_label "$1") || {
    echo "❌ No label provided and no latest git-lock exists"
    return 1
  }

  lock_file="$lock_dir/${repo_id}-${label}.lock"
  if [[ ! -f "$lock_file" ]]; then
    echo "❌ git-lock [$label] not found"
    return 1
  fi

  local content hash note timestamp subject
  content=$(<"$lock_file")
  hash=$(echo "$content" | sed -n '1p' | cut -d '#' -f1 | xargs)
  note=$(echo "$content" | sed -n '1p' | cut -d '#' -f2- | xargs)
  timestamp=$(echo "$content" | grep '^timestamp=' | cut -d '=' -f2-)
  subject=$(git log -1 --pretty=%s "$hash" 2>/dev/null)

  echo "🗑️  Candidate for deletion:"
  printf "   🏷️  tag:     %s\n" "$label"
  printf "   🧬 commit:  %s\n" "$hash"
  [[ -n "$subject" ]] && printf "   📄 message: %s\n" "$subject"
  [[ -n "$note" ]] && printf "   📝 note:    %s\n" "$note"
  [[ -n "$timestamp" ]] && printf "   📅 time:    %s\n" "$timestamp"
  echo

  read -r -p "⚠️  Delete this git-lock? [y/N] " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "🚫 Aborted"
    return 1
  fi

  rm -f "$lock_file"
  echo "🗑️  Deleted git-lock [$repo_id:$label]"

  if [[ -f "$latest_file" ]]; then
    latest_label=$(<"$latest_file")
    if [[ "$label" == "$latest_label" ]]; then
      rm -f "$latest_file"
      echo "🧼 Removed latest marker (was [$label])"
    fi
  fi
}

# Compare two git-locks by label and show their commit diff (log)
#
# Usage:
#   git-lock-diff <label1> <label2>
#
# This will show the commits between the two git-lock points using: git log <hash1>..<hash2>
_git_lock_diff() {
  local repo_id lock_dir label1 label2 file1 file2 hash1 hash2

  label1=$(_git_lock_resolve_label "$1") || {
    echo "❗ Usage: git-lock diff <label1> <label2>"
    return 1
  }
  label2=$(_git_lock_resolve_label "$2") || {
    echo "❗ Second label not provided or found"
    return 1
  }

  repo_id=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
  lock_dir="$ZSH_CACHE_DIR/git-locks"
  file1="$lock_dir/${repo_id}-${label1}.lock"
  file2="$lock_dir/${repo_id}-${label2}.lock"

  [[ -f "$file1" ]] || {
    echo "❌ git-lock [$label1] not found for [$repo_id]"
    return 1
  }
  [[ -f "$file2" ]] || {
    echo "❌ git-lock [$label2] not found for [$repo_id]"
    return 1
  }

  hash1=$(sed -n '1p' "$file1" | cut -d '#' -f1 | xargs)
  hash2=$(sed -n '1p' "$file2" | cut -d '#' -f1 | xargs)

  echo "🧮 Comparing commits: [$repo_id:$label1] → [$label2]"
  echo "   🔖 $label1: $hash1"
  echo "   🔖 $label2: $hash2"
  echo

  git log --oneline --graph --decorate "$hash1..$hash2"
}

# git-lock-tag: Create a git tag from a saved git-lock lock file
#
# Usage:
#   git-lock-tag <git-lock-label> <tag-name> [-m <tag-message>] [--push]
#
# - <git-lock-label>: Label of the saved git-lock (e.g., "111")
# - <tag-name>: Name of the git tag to create
# - -m: Optional tag message; if omitted, uses the commit's subject
# - --push: Pushes the tag to origin, then deletes the local tag
#
# Behavior:
# - Reads commit hash from lock file at $ZSH_CACHE_DIR/git-locks/<repo>-<label>.lock
# - Falls back to the commit subject as the tag message if none is provided
# - Prompts before overwriting existing tags

_git_lock_tag() {
  local label tag_name tag_msg="" do_push=false
  local repo_id lock_dir lock_file hash timestamp line1
  local -a positional=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --push)
        do_push=true
        shift ;;
      -m)
        shift
        tag_msg="$1"
        shift ;;
      *)
        positional+=("$1")
        shift ;;
    esac
  done

  label=$(_git_lock_resolve_label "${positional[0]}") || {
    echo "❌ git-lock label not provided or not found"
    return 1
  }

  tag_name="${positional[1]}"
  [[ -z "$tag_name" ]] && {
    echo "❗ Usage: git-lock-tag <git-lock-label> <tag-name> [-m <tag-message>] [--push]"
    return 1
  }

  repo_id=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
  lock_dir="$ZSH_CACHE_DIR/git-locks"
  lock_file="$lock_dir/${repo_id}-${label}.lock"

  [[ -f "$lock_file" ]] || {
    echo "❌ git-lock [$label] not found in [$lock_dir] for [$repo_id]"
    return 1
  }

  line1=$(sed -n '1p' "$lock_file")
  hash=$(cut -d '#' -f1 <<< "$line1" | xargs)
  timestamp=$(grep '^timestamp=' "$lock_file" | cut -d '=' -f2-)

  [[ -z "$tag_msg" ]] && tag_msg=$(git show -s --format=%s "$hash")

  if git rev-parse "$tag_name" >/dev/null 2>&1; then
    echo "⚠️  Git tag [$tag_name] already exists."
    read "confirm?❓ Overwrite it? [y/N] "
    [[ "$confirm" != [yY] ]] && {
      echo "🚫 Aborted"
      return 1
    }
    git tag -d "$tag_name" || {
      echo "❌ Failed to delete existing tag [$tag_name]"
      return 1
    }
  fi

  git tag -a "$tag_name" "$hash" -m "$tag_msg"
  echo "🏷️  Created tag [$tag_name] at commit [$hash]"
  echo "📝 Message: $tag_msg"

  if $do_push; then
    git push origin "$tag_name"
    echo "🚀 Pushed tag [$tag_name] to origin"
    git tag -d "$tag_name" && echo "🧹 Deleted local tag [$tag_name]"
  fi
}

git-lock() {
  if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❗ Not a Git repository. Run this command inside a Git project."
    return 1
  fi

  local cmd="$1"
  shift

  case "$cmd" in
    ""|help|-h|--help)
      echo "Usage: git-lock <command> [args...]"
      echo ""
      echo "Commands:"
      echo "  lock [label] [note] [commit]      Save commit hash to lock"
      echo "  unlock [label]                    Reset to a saved commit"
      echo "  list                              Show all locks for repo"
      echo "  copy <from> <to>                  Duplicate a lock label"
      echo "  delete [label]                    Remove a lock"
      echo "  diff <label1> <label2>            Compare commits between two locks"
      echo "  tag <label> <tag> [-m msg]        Create git tag from a lock"
      echo ""
      return 0 ;;
    lock)
      _git_lock "$@" ;;
    unlock)
      _git_lock_unlock "$@" ;;
    list)
      _git_lock_list "$@" ;;
    copy)
      _git_lock_copy "$@" ;;
    delete)
      _git_lock_delete "$@" ;;
    diff)
      _git_lock_diff "$@" ;;
    tag)
      _git_lock_tag "$@" ;;
    *)
      echo "❗ Unknown command: '$cmd'"
      echo "Run 'git-lock help' for usage."
      return 1 ;;
  esac
}
