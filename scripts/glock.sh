# ────────────────────────────────────────────────────────
# Git lock / unlock helpers (manual commit fallback, repo-safe)
# ────────────────────────────────────────────────────────

# Save the current commit hash into a named lock file
# - Allows optional label (default is "default")
# - Optional note can be recorded
# - Optional commit hash can be specified (default is HEAD)
# - A timestamp is stored for reference
# - The most recent glock label is saved to a "-latest" file
# - Lock files are stored under $ZSH_CACHE_DIR/glocks
#
# Example:
#   glock dev "before hotfix"
#   glock hotfix "old code" HEAD~2
#   glock release "tag version" v1.0.0
_glock_lock() {
  local label note commit repo_id lock_dir lock_file latest_file timestamp hash

  label="${1:-default}"
  note="$2"
  commit="${3:-HEAD}"

  repo_id=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
  lock_dir="$ZSH_CACHE_DIR/glocks"
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
_glock_unlock() {
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
# - Includes commit hash, note, timestamp, and commit subject
# - Highlights the latest label with ⭐
#
# Example:
#   glock-list
_glock_lock() {
  local label note commit repo_id lock_dir lock_file latest_file timestamp hash

  label="${1:-default}"
  note="$2"
  commit="${3:-HEAD}"

  repo_id=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
  lock_dir="$ZSH_CACHE_DIR/glocks"
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

_glock_unlock() {
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

_glock_list() {
  local repo_id lock_dir latest
  repo_id=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
  lock_dir="$ZSH_CACHE_DIR/glocks"

  [[ -d "$lock_dir" ]] || {
    echo "📬 No glocks found for [$repo_id]"
    return 0
  }

  [[ -f "$lock_dir/${repo_id}-latest" ]] && latest=$(<"$lock_dir/${repo_id}-latest")

  # Test without for loop, just declare local variables
  local tag hash note timestamp subject

  # Check the local variables
  echo "🔐 [TEST] Glock list for [$repo_id]:"
  echo "tag: $tag"
  echo "hash: $hash"
  echo "note: $note"
  echo "timestamp: $timestamp"
  echo "subject: $subject"
}

_glock_list() {
  local repo_id lock_dir latest
  repo_id=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
  lock_dir="$ZSH_CACHE_DIR/glocks"

  [[ -d "$lock_dir" ]] || {
    echo "📬 No glocks found for [$repo_id]"
    return 0
  }

  [[ -f "$lock_dir/${repo_id}-latest" ]] && latest=$(cat "$lock_dir/${repo_id}-latest")

  local file tmp_list=()
  for file in "$lock_dir/${repo_id}-"*.lock; do
    [[ -e "$file" && "$(basename "$file")" != "${repo_id}-latest.lock" ]] || continue
    local ts_line epoch
    ts_line=$(grep '^timestamp=' "$file")
    timestamp=${ts_line#timestamp=}
    epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "$timestamp" "+%s" 2>/dev/null || date -d "$timestamp" "+%s")
    tmp_list+=("$epoch|$file")
  done

  IFS=$'\n' sorted=($(printf '%s\n' "${tmp_list[@]}" | sort -rn))

  if [[ ${#sorted[@]} -eq 0 ]]; then
    echo "📬 No glocks found for [$repo_id]"
    return 0
  fi

  echo "🔐 Glock list for [$repo_id]:"
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
    [[ -n "$timestamp" ]] && printf "   ⏰ time:    %s\n" "$timestamp"
  done
}

# Copy an existing glock to a new label (preserving all metadata)
# - Copies both hash and note content as-is to a new lock file
# - Prompts before overwrite if the target already exists
# - Sets the copied label as latest
#
# Example:
#   glock-copy dev staging
_glock_copy() {
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

  local content hash note timestamp subject
  content=$(<"$src_file")
  hash=$(echo "$content" | sed -n '1p' | cut -d '#' -f1 | xargs)
  note=$(echo "$content" | sed -n '1p' | cut -d '#' -f2- | xargs)
  timestamp=$(echo "$content" | grep '^timestamp=' | cut -d '=' -f2-)
  subject=$(git log -1 --pretty=%s "$hash" 2>/dev/null)

  echo "📋 Copied glock [$repo_id:$src_label] → [$repo_id:$dst_label]"
  printf "   🏷️  tag:     %s → %s\n" "$src_label" "$dst_label"
  printf "   🧬 commit:  %s\n" "$hash"
  [[ -n "$subject" ]] && printf "   📄 message: %s\n" "$subject"
  [[ -n "$note" ]] && printf "   📝 note:    %s\n" "$note"
  [[ -n "$timestamp" ]] && printf "   ⏰ time:    %s\n" "$timestamp"
}


# Delete a glock by label or the most recent one
# - Displays details of the glock before deletion (hash, note, timestamp)
# - Prompts for confirmation before deletion
# - Removes latest marker if the deleted one was the latest
#
# Example:
#   glock-delete dev
_glock_delete() {
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
  [[ -n "$timestamp" ]] && printf "   ⏰ time:    %s\n" "$timestamp"
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
_glock_diff() {
  local label1 label2 repo_id lock_dir file1 file2 hash1 hash2

  if [[ -z "$1" || -z "$2" ]]; then
    echo "❗ Usage: glock diff <label1> <label2>"
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

# glock-tag: Create a git tag from a saved glock lock file
#
# Usage:
#   glock-tag <glock-label> <tag-name> [-m <tag-message>] [--push]
#
# - <glock-label>: Label of the saved glock (e.g., "111")
# - <tag-name>: Name of the git tag to create
# - -m: Optional tag message; if omitted, uses the commit's subject
# - --push: Pushes the tag to origin, then deletes the local tag
#
# Behavior:
# - Reads commit hash from lock file at $ZSH_CACHE_DIR/glocks/<repo>-<label>.lock
# - Falls back to the commit subject as the tag message if none is provided
# - Prompts before overwriting existing tags

_glock_tag() {
  local label tag_name tag_msg=""
  local do_push=false
  local repo_id lock_dir lock_file hash timestamp line1
  local -a positional=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --push)
        do_push=true
        shift
        ;;
      -m)
        shift
        tag_msg="$1"
        shift
        ;;
      *)
        positional+=("$1")
        shift
        ;;
    esac
  done

  label="${positional[1]}"
  tag_name="${positional[2]}"

  if [[ -z "$label" || -z "$tag_name" ]]; then
    echo "❌ Usage: glock-tag <glock-label> <tag-name> [-m <tag-message>] [--push]"
    return 1
  fi

  repo_id=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
  : "${ZSH_CACHE_DIR:=$HOME/.config/zsh/cache}"
  lock_dir="$ZSH_CACHE_DIR/glocks"
  lock_file="$lock_dir/${repo_id}-${label}.lock"

  if [[ ! -f "$lock_file" ]]; then
    echo "❌ Glock label [$label] not found in [$lock_dir] for repo [$repo_id]"
    return 1
  fi

  line1=$(sed -n '1p' "$lock_file")
  hash=$(cut -d '#' -f1 <<< "$line1" | xargs)
  timestamp=$(grep '^timestamp=' "$lock_file" | cut -d '=' -f2-)

  if [[ -z "$tag_msg" ]]; then
    tag_msg=$(git show -s --format=%s "$hash")
  fi

  if git rev-parse "$tag_name" >/dev/null 2>&1; then
    echo "⚠️  Git tag [$tag_name] already exists."
    read "confirm?❓ Overwrite it? [y/N] "
    if [[ -z "$confirm" || "$confirm" != [yY] ]]; then
      echo "🚫 Aborted"
      return 1
    fi
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

glock() {
  local cmd="$1"
  shift

  case "$cmd" in
    ""|help|-h|--help)
      echo "Usage: glock <command> [args...]"
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
      _glock_lock "$@" ;;
    unlock)
      _glock_unlock "$@" ;;
    list)
      _glock_list "$@" ;;
    copy)
      _glock_copy "$@" ;;
    delete)
      _glock_delete "$@" ;;
    diff)
      _glock_diff "$@" ;;
    tag)
      _glock_tag "$@" ;;
    *)
      echo "❗ Unknown command: '$cmd'"
      echo "Run 'glock help' for usage."
      return 1 ;;
  esac
}
