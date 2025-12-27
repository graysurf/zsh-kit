#!/usr/bin/env -S zsh -f

# Only define once
typeset -f plugin_fetch_if_missing_from_entry >/dev/null && return

# plugin_fetcher.zsh – fetch/update Zsh plugins

ZSH_PLUGINS_DIR="${ZSH_PLUGINS_DIR:-$ZDOTDIR/plugins}"
PLUGIN_FETCH_DRY_RUN="${PLUGIN_FETCH_DRY_RUN:-false}"
PLUGIN_FETCH_FORCE="${PLUGIN_FETCH_FORCE:-false}"
PLUGIN_UPDATE_FILE="$ZSH_CACHE_DIR/plugin.timestamp"

# Fetch plugin if not present, or force-refetch if requested
plugin_fetch_if_missing_from_entry() {
  typeset entry="$1"
  typeset -a parts
  typeset plugin_name git_url

  parts=("${(@s/::/)entry}")
  plugin_name="${parts[1]}"

  for part in "${parts[@]:2}"; do
    if [[ "$part" == git=* ]]; then
      git_url="${part#git=}"
    fi
  done

  typeset plugin_path="$ZSH_PLUGINS_DIR/$plugin_name"

  if [[ "$PLUGIN_FETCH_FORCE" == true && -d "$plugin_path" ]]; then
    printf "💥 Forcing re-clone: %s\n" "$plugin_name"
    [[ "$PLUGIN_FETCH_DRY_RUN" == false ]] && rm -rf "$plugin_path"
  fi

  if [[ -d "$plugin_path" ]]; then
    return 0
  fi

  if [[ -n "$git_url" ]]; then
    printf "🌐 Cloning %s from %s\n" "$plugin_name" "$git_url"
    if [[ "$PLUGIN_FETCH_DRY_RUN" == false ]]; then
      git clone "$git_url" "$plugin_path" || {
        printf "❌ Failed to clone: %s\n" "$plugin_name"
        return 1
      }

      if [[ -f "$plugin_path/.gitmodules" ]]; then
        printf "🔗 Initializing submodules for %s\n" "$plugin_name"
        git -C "$plugin_path" submodule update --init --recursive || {
          printf "❌ Failed to init submodules for: %s\n" "$plugin_name"
          return 1
        }
      fi
    fi
  else
    printf "⚠️  No git URL defined for: %s\n" "$plugin_name"
  fi
}

plugin_update_all() {
  emulate -L zsh
  setopt pipe_fail err_return nounset null_glob

  typeset plugins_dir=''
  plugins_dir="$ZSH_PLUGINS_DIR"
  [[ -d "$plugins_dir" ]] || return 0

  printf "🔄 Updating plugins in: %s\n\n" "$plugins_dir"
  for dir in "$plugins_dir"/*(/N); do
    [[ -d "$dir/.git" ]] || continue
    plugin_name="${dir##*/}"
    printf "🔧 Updating %s ...\n" "$plugin_name"

    if [[ "$PLUGIN_FETCH_DRY_RUN" == true ]]; then
      printf "    ↪ [dry-run] git -C %s pull --ff-only\n" "$dir"
      continue
    fi

    before=$(git -C "$dir" rev-parse HEAD 2>/dev/null)

    if output=$(git -C "$dir" pull --ff-only 2>&1); then
      after=$(git -C "$dir" rev-parse HEAD 2>/dev/null)
      short_after="${after:0:7}"
      if [[ "$before" == "$after" ]]; then
        if grep -q "Already up to date" <<< "$output"; then
          printf "    ↪ Already up to date. (at %s)\n" "$short_after"
        else
          printf "%s\n" "$output" | sed 's/^/    ↪ /'
        fi
      else
        printf "    ↪ Updated to %s\n" "$short_after"
      fi
    else
      printf "%s\n" "$output" | sed 's/^/    ❌ /'
      printf "    ❌ Failed to update %s\n" "$plugin_name"
    fi
  done
}

plugin_maybe_auto_update() {
  typeset now_epoch last_epoch

  now_epoch=$(date +%s)

  if [[ -f "$PLUGIN_UPDATE_FILE" ]]; then
    last_epoch=$(<"$PLUGIN_UPDATE_FILE")
  else
    last_epoch=0
  fi

  if (( now_epoch - last_epoch > 7 * 86400 )); then
    printf "📦 Auto-updating Zsh plugins (last update over 7 days ago)...\n\n"
    plugin_update_all
    printf "%s\n" "$now_epoch" > "$PLUGIN_UPDATE_FILE"
  fi
}

plugin_print_status() {
  if [[ ! -f "$PLUGIN_UPDATE_FILE" ]]; then
    printf "📦 Plugin update status: never updated\n"
    printf "⏱  Next auto-update expected: now\n"
    return
  fi

  now_epoch=$(date +%s)
  last_epoch=$(<"$PLUGIN_UPDATE_FILE")
  days_ago=$(( (now_epoch - last_epoch) / 86400 ))
  days_left=$(( 30 - days_ago ))
  last_date=$(date -j -f %s "$last_epoch" +"%Y-%m-%d" 2>/dev/null || date -d "@$last_epoch" +"%Y-%m-%d")

  printf "📦 Plugin last updated: %s (%d days ago)\n" "$last_date" "$days_ago"
  if (( days_left <= 0 )); then
    printf "⏱  Next auto-update expected: now\n"
  else
    printf "⏱  Next auto-update expected in: %d days\n" "$days_left"
  fi
}
