# Only define once
typeset -f plugin_fetch_if_missing_from_entry >/dev/null && return

# plugin_fetcher.sh – fetch/update Zsh plugins

ZSH_PLUGINS_DIR="${ZSH_PLUGINS_DIR:-$ZDOTDIR/plugins}"
PLUGIN_FETCH_DRY_RUN="${PLUGIN_FETCH_DRY_RUN:-false}"
PLUGIN_FETCH_FORCE="${PLUGIN_FETCH_FORCE:-false}"
PLUGIN_UPDATE_FILE="$ZSH_CACHE_DIR/plugin.last_update"

# Fetch plugin if not present, or force-refetch if requested
plugin_fetch_if_missing_from_entry() {
  typeset entry="$1"
  typeset plugin_name git_url

  IFS='::' read -A parts <<< "$entry"
  plugin_name="${parts[1]}"

  for part in "${parts[@]:2}"; do
    [[ "$part" == git=* ]] && git_url="${part#git=}"
  done

  typeset path="$ZSH_PLUGINS_DIR/$plugin_name"

  if [[ "$PLUGIN_FETCH_FORCE" == true && -d "$path" ]]; then
    echo "💥 Forcing re-clone: $plugin_name"
    [[ "$PLUGIN_FETCH_DRY_RUN" == false ]] && rm -rf "$path"
  fi

  if [[ -d "$path" ]]; then
    return 0
  fi

  if [[ -n "$git_url" ]]; then
    echo "🌐 Cloning $plugin_name from $git_url"
    [[ "$PLUGIN_FETCH_DRY_RUN" == false ]] && \
      git clone --depth=1 "$git_url" "$path" || {
        echo "❌ Failed to clone: $plugin_name"
        return 1
      }
  else
    echo "⚠️  No git URL defined for: $plugin_name"
  fi
}

plugin_update_all() {
  echo -e "🔄 Updating plugins in: $ZSH_PLUGINS_DIR\n"
  for dir in "$ZSH_PLUGINS_DIR"/*; do
    [[ -d "$dir/.git" ]] || continue
    plugin_name="${dir##*/}"
    echo -e "🔧 Updating $plugin_name ..."

    if [[ "$PLUGIN_FETCH_DRY_RUN" == true ]]; then
      echo -e "    ↪ [dry-run] git -C $dir pull --ff-only"
      continue
    fi

    before=$(git -C "$dir" rev-parse HEAD 2>/dev/null)

    if output=$(git -C "$dir" pull --ff-only 2>&1); then
      after=$(git -C "$dir" rev-parse HEAD 2>/dev/null)
      short_after="${after:0:7}"
      if [[ "$before" == "$after" ]]; then
        if grep -q "Already up to date" <<< "$output"; then
          echo -e "    ↪ Already up to date. (at $short_after)"
        else
          echo -e "$output" | sed 's/^/    ↪ /'
        fi
      else
        echo -e "    ↪ Updated to $short_after"
      fi
    else
      echo -e "$output" | sed 's/^/    ❌ /'
      echo -e "    ❌ Failed to update $plugin_name"
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
    echo -e "📦 Auto-updating Zsh plugins (last update over 7 days ago)...\n"
    plugin_update_all
    echo -e "$now_epoch" > "$PLUGIN_UPDATE_FILE"
  fi
}

plugin_print_status() {
  if [[ ! -f "$PLUGIN_UPDATE_FILE" ]]; then
    echo "📦 Plugin update status: never updated"
    echo "⏱  Next auto-update expected: now"
    return
  fi

  now_epoch=$(date +%s)
  last_epoch=$(<"$PLUGIN_UPDATE_FILE")
  days_ago=$(( (now_epoch - last_epoch) / 86400 ))
  days_left=$(( 30 - days_ago ))
  last_date=$(date -j -f %s "$last_epoch" +"%Y-%m-%d" 2>/dev/null || date -d "@$last_epoch" +"%Y-%m-%d")

  echo "📦 Plugin last updated: $last_date ($days_ago days ago)"
  if (( days_left <= 0 )); then
    echo "⏱  Next auto-update expected: now"
  else
    echo "⏱  Next auto-update expected in: $days_left days"
  fi
}

