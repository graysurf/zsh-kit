# ────────────────────────────────────────────────────────
# Git lock / unlock helpers (manual commit fallback, repo-safe)
# ────────────────────────────────────────────────────────


# ────────────────────────────────────────────────────────
# Aliases and Unalias
# ────────────────────────────────────────────────────────
if command -v safe_unalias >/dev/null; then
  safe_unalias _git_lock
fi

# Resolve label from argument or latest fallback
_git_lock_resolve_label() {
  typeset input_label="$1"
  typeset repo_id lock_dir latest_file

  repo_id=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
  lock_dir="$ZSH_CACHE_DIR/git-locks"
  [[ -d "$lock_dir" ]] || mkdir -p "$lock_dir"
  latest_file="$lock_dir/${repo_id}-latest"

  if [[ -n "$input_label" ]]; then
    printf "%s\n" "$input_label"
  elif [[ -f "$latest_file" ]]; then
    cat "$latest_file"
  else
    return 1
  fi
}


# Display a list of all saved git-locks (labels) in the current repository
# - Includes commit hash, note, timestamp, and commit subject
# - Highlights the latest label with ⭐
#
# Example:
#   git-lock-list
_git_lock() {
  typeset label note commit repo_id lock_dir lock_file latest_file timestamp hash

  label="${1:-default}"
  note="$2"
  commit="${3:-HEAD}"

  repo_id=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
  lock_dir="$ZSH_CACHE_DIR/git-locks"
  lock_file="$lock_dir/${repo_id}-${label}.lock"
  latest_file="$lock_dir/${repo_id}-latest"
  timestamp=$(date "+%Y-%m-%d %H:%M:%S")

  hash=$(git rev-parse "$commit" 2>/dev/null) || {
    printf "❌ Invalid commit: %s\n" "$commit"
    return 1
  }

  [[ -d "$lock_dir" ]] || mkdir -p "$lock_dir"

  {
    printf "%s # %s\n" "$hash" "$note"
    printf "timestamp=%s\n" "$timestamp"
  } > "$lock_file"

  printf "%s\n" "$label" > "$latest_file"

  printf "🔐 [%s:%s] Locked: %s" "$repo_id" "$label" "$hash"
  [[ -n "$note" ]] && printf "  # %s" "$note"
  printf "\n"
  printf "    at %s\n" "$timestamp"
}

_git_lock_unlock() {
  typeset label repo_id lock_dir lock_file latest_file
  repo_id=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
  lock_dir="$ZSH_CACHE_DIR/git-locks"
  latest_file="$lock_dir/${repo_id}-latest"

  [[ -d "$lock_dir" ]] || mkdir -p "$lock_dir"

  if [[ -n "$1" ]]; then
    label="$1"
  elif [[ -f "$latest_file" ]]; then
    label=$(cat "$latest_file")
  else
    printf "❌ No recent git-lock found for %s\n" "$repo_id"
    return 1
  fi

  lock_file="$lock_dir/${repo_id}-${label}.lock"
  if [[ ! -f "$lock_file" ]]; then
    printf "❌ No git-lock named '%s' found for %s\n" "$label" "$repo_id"
    return 1
  fi

  typeset hash note msg
  read -r line < "$lock_file"
  hash=$(echo "$line" | cut -d '#' -f 1 | xargs)
  note=$(echo "$line" | cut -d '#' -f 2- | xargs)
  msg=$(git log -1 --pretty=format:"%s" "$hash" 2>/dev/null)

  printf "🔐 Found [%s:%s] → %s\n" "$repo_id" "$label" "$hash"
  [[ -n "$note" ]] && printf "    # %s\n" "$note"
  [[ -n "$msg" ]] && printf "    commit message: %s\n" "$msg"
  printf "\n"

  printf "⚠️  Hard reset to [%s]? [y/N] " "$label"
  read -r confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    printf "🚫 Aborted\n"
    return 1
  fi

  git reset --hard "$hash"
  printf "⏪ [%s:%s] Reset to: %s\n" "$repo_id" "$label" "$hash"
}


_git_lock_list() {
  typeset repo_id lock_dir latest
  repo_id=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
  lock_dir="$ZSH_CACHE_DIR/git-locks"

  [[ -d "$lock_dir" ]] || {
    printf "📬 No git-locks found for [%s]\n" "$repo_id"
    return 0
  }

  [[ -f "$lock_dir/${repo_id}-latest" ]] && latest=$(cat "$lock_dir/${repo_id}-latest")

  typeset file tmp_list=()
  for file in "$lock_dir/${repo_id}-"*.lock; do
    [[ -e "$file" && "$(basename "$file")" != "${repo_id}-latest.lock" ]] || continue
    typeset ts_line='' epoch=''
    ts_line=$(grep '^timestamp=' "$file")
    timestamp=${ts_line#timestamp=}
    epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "$timestamp" "+%s" 2>/dev/null || date -d "$timestamp" "+%s")
    tmp_list+=("$epoch|$file")
  done

  IFS=$'\n' sorted=($(printf '%s\n' "${tmp_list[@]}" | sort -rn))

  if [[ ${#sorted[@]} -eq 0 ]]; then
    printf "📬 No git-locks found for [%s]\n" "$repo_id"
    return 0
  fi

  printf "🔐 git-lock list for [%s]:\n" "$repo_id"
  for item in "${sorted[@]}"; do
    file="${item#*|}"
    typeset name='' hash='' note='' timestamp='' label='' subject='' line=''
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
  typeset repo_id lock_dir src_label dst_label src_file dst_file
  repo_id=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
  lock_dir="$ZSH_CACHE_DIR/git-locks"

  [[ -d "$lock_dir" ]] || {
    printf "❌ No git-locks found\n"
    return 1
  }

  src_label=$(_git_lock_resolve_label "$1") || {
    printf "❗ Usage: git-lock-copy <source-label> <target-label>\n"
    return 1
  }
  dst_label="$2"
  [[ -z "$dst_label" ]] && {
    printf "❗ Target label is missing\n"
    return 1
  }

  src_file="$lock_dir/${repo_id}-${src_label}.lock"
  dst_file="$lock_dir/${repo_id}-${dst_label}.lock"

  if [[ ! -f "$src_file" ]]; then
    printf "❌ Source git-lock [%s:%s] not found\n" "$repo_id" "$src_label"
    return 1
  fi

  if [[ -f "$dst_file" ]]; then
    printf "⚠️  Target git-lock [%s:%s] already exists. Overwrite? [y/N] " "$repo_id" "$dst_label"
    read -r confirm
    [[ "$confirm" != [yY] ]] && {
      printf "🚫 Aborted\n"
      return 1
    }
  fi

  cp "$src_file" "$dst_file"
  printf "%s\n" "$dst_label" > "$lock_dir/${repo_id}-latest"

  typeset content hash note timestamp subject
  content=$(<"$src_file")
  hash=$(echo "$content" | sed -n '1p' | cut -d '#' -f1 | xargs)
  note=$(echo "$content" | sed -n '1p' | cut -d '#' -f2- | xargs)
  timestamp=$(echo "$content" | grep '^timestamp=' | cut -d '=' -f2-)
  subject=$(git log -1 --pretty=%s "$hash" 2>/dev/null)

  printf "📋 Copied git-lock [%s:%s] → [%s:%s]\n" "$repo_id" "$src_label" "$repo_id" "$dst_label"
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
  typeset repo_id lock_dir label lock_file latest_file latest_label
  repo_id=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
  lock_dir="$ZSH_CACHE_DIR/git-locks"
  latest_file="$lock_dir/${repo_id}-latest"

  [[ -d "$lock_dir" ]] || {
    printf "❌ No git-locks found\n"
    return 1
  }

  label=$(_git_lock_resolve_label "$1") || {
    printf "❌ No label provided and no latest git-lock exists\n"
    return 1
  }

  lock_file="$lock_dir/${repo_id}-${label}.lock"
  if [[ ! -f "$lock_file" ]]; then
    printf "❌ git-lock [%s] not found\n" "$label"
    return 1
  fi

  typeset content hash note timestamp subject
  content=$(<"$lock_file")
  hash=$(echo "$content" | sed -n '1p' | cut -d '#' -f1 | xargs)
  note=$(echo "$content" | sed -n '1p' | cut -d '#' -f2- | xargs)
  timestamp=$(echo "$content" | grep '^timestamp=' | cut -d '=' -f2-)
  subject=$(git log -1 --pretty=%s "$hash" 2>/dev/null)

  printf "🗑️  Candidate for deletion:\n"
  printf "   🏷️  tag:     %s\n" "$label"
  printf "   🧬 commit:  %s\n" "$hash"
  [[ -n "$subject" ]] && printf "   📄 message: %s\n" "$subject"
  [[ -n "$note" ]] && printf "   📝 note:    %s\n" "$note"
  [[ -n "$timestamp" ]] && printf "   📅 time:    %s\n" "$timestamp"
  printf "\n"

  read -r -p "⚠️  Delete this git-lock? [y/N] " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    printf "🚫 Aborted\n"
    return 1
  fi

  rm -f "$lock_file"
  printf "🗑️  Deleted git-lock [%s:%s]\n" "$repo_id" "$label"

  if [[ -f "$latest_file" ]]; then
    latest_label=$(<"$latest_file")
    if [[ "$label" == "$latest_label" ]]; then
      rm -f "$latest_file"
      printf "🧼 Removed latest marker (was [%s])\n" "$label"
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
  typeset repo_id lock_dir label1 label2 file1 file2 hash1 hash2

  label1=$(_git_lock_resolve_label "$1") || {
    printf "❗ Usage: git-lock diff <label1> <label2>\n"
    return 1
  }
  label2=$(_git_lock_resolve_label "$2") || {
    printf "❗ Second label not provided or found\n"
    return 1
  }

  repo_id=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
  lock_dir="$ZSH_CACHE_DIR/git-locks"
  file1="$lock_dir/${repo_id}-${label1}.lock"
  file2="$lock_dir/${repo_id}-${label2}.lock"

  [[ -f "$file1" ]] || {
    printf "❌ git-lock [%s] not found for [%s]\n" "$label1" "$repo_id"
    return 1
  }
  [[ -f "$file2" ]] || {
    printf "❌ git-lock [%s] not found for [%s]\n" "$label2" "$repo_id"
    return 1
  }

  hash1=$(sed -n '1p' "$file1" | cut -d '#' -f1 | xargs)
  hash2=$(sed -n '1p' "$file2" | cut -d '#' -f1 | xargs)

  printf "🧮 Comparing commits: [%s:%s] → [%s]\n" "$repo_id" "$label1" "$label2"
  printf "   🔖 %s: %s\n" "$label1" "$hash1"
  printf "   🔖 %s: %s\n" "$label2" "$hash2"
  printf "\n"

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
  typeset label tag_name tag_msg="" do_push=false
  typeset repo_id lock_dir lock_file hash timestamp line1
  typeset -a positional=()

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
    printf "❌ git-lock label not provided or not found\n"
    return 1
  }

  tag_name="${positional[1]}"
  [[ -z "$tag_name" ]] && {
    printf "❗ Usage: git-lock-tag <git-lock-label> <tag-name> [-m <tag-message>] [--push]\n"
    return 1
  }

  repo_id=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
  lock_dir="$ZSH_CACHE_DIR/git-locks"
  lock_file="$lock_dir/${repo_id}-${label}.lock"

  [[ -f "$lock_file" ]] || {
    printf "❌ git-lock [%s] not found in [%s] for [%s]\n" "$label" "$lock_dir" "$repo_id"
    return 1
  }

  line1=$(sed -n '1p' "$lock_file")
  hash=$(cut -d '#' -f1 <<< "$line1" | xargs)
  timestamp=$(grep '^timestamp=' "$lock_file" | cut -d '=' -f2-)

  [[ -z "$tag_msg" ]] && tag_msg=$(git show -s --format=%s "$hash")

  if git rev-parse "$tag_name" >/dev/null 2>&1; then
    printf "⚠️  Git tag [%s] already exists.\n" "$tag_name"
    printf "❓ Overwrite it? [y/N] "
    read -r confirm
    [[ "$confirm" != [yY] ]] && {
      printf "🚫 Aborted\n"
      return 1
    }
    git tag -d "$tag_name" || {
      printf "❌ Failed to delete existing tag [%s]\n" "$tag_name"
      return 1
    }
  fi

  git tag -a "$tag_name" "$hash" -m "$tag_msg"
  printf "🏷️  Created tag [%s] at commit [%s]\n" "$tag_name" "$hash"
  printf "📝 Message: %s\n" "$tag_msg"

  if $do_push; then
    git push origin "$tag_name"
    printf "🚀 Pushed tag [%s] to origin\n" "$tag_name"
    git tag -d "$tag_name" && printf "🧹 Deleted local tag [%s]\n" "$tag_name"
  fi
}

git-lock() {
  if ! git rev-parse --git-dir > /dev/null 2>&1; then
    printf "❗ Not a Git repository. Run this command inside a Git project.\n"
    return 1
  fi

  typeset cmd="$1"
  if [[ -z "$cmd" || "$cmd" == "help" || "$cmd" == "--help" || "$cmd" == "-h" ]]; then
    printf "Usage: git-lock <command> [args...]\n"
    printf "\n"
    printf "Commands:\n"
    printf "  %-30s %s\n" \
      "lock [label] [note] [commit]"   "Save commit hash to lock" \
      "unlock [label]"                 "Reset to a saved commit" \
      "list"                           "Show all locks for repo" \
      "copy <from> <to>"              "Duplicate a lock label" \
      "delete [label]"                "Remove a lock" \
      "diff <label1> <label2>"        "Compare commits between two locks" \
      "tag <label> <tag> [-m msg]"    "Create git tag from a lock"
    printf "\n"
    return 0
  fi

  shift

  case "$cmd" in
    lock)    _git_lock "$@" ;;
    unlock)  _git_lock_unlock "$@" ;;
    list)    _git_lock_list "$@" ;;
    copy)    _git_lock_copy "$@" ;;
    delete)  _git_lock_delete "$@" ;;
    diff)    _git_lock_diff "$@" ;;
    tag)     _git_lock_tag "$@" ;;
    *)
      printf "❗ Unknown command: '%s'\n" "$cmd"
      printf "Run 'git-lock help' for usage.\n"
      return 1 ;;
  esac
}
