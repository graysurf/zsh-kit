#!/usr/bin/env -S zsh -f

# Only define once
typeset -f plugin_fetch_if_missing_from_entry >/dev/null && return

# plugin_fetcher.zsh – fetch/update Zsh plugins

ZSH_PLUGINS_DIR="${ZSH_PLUGINS_DIR:-$ZDOTDIR/plugins}"
PLUGIN_FETCH_DRY_RUN_ENABLED="${PLUGIN_FETCH_DRY_RUN_ENABLED-false}"
PLUGIN_FETCH_FORCE_ENABLED="${PLUGIN_FETCH_FORCE_ENABLED-false}"
PLUGIN_UPDATE_FILE="$ZSH_CACHE_DIR/plugin.timestamp"

# plugin_fetch_if_missing_from_entry <entry>
# Ensure the plugin referenced by a `config/plugins.list` entry exists under $ZSH_PLUGINS_DIR.
# Usage: plugin_fetch_if_missing_from_entry <entry>
# Env:
# - ZSH_PLUGINS_DIR: plugin base directory (default: $ZDOTDIR/plugins)
# - PLUGIN_FETCH_DRY_RUN_ENABLED: when true, do not modify filesystem (default: false)
# - PLUGIN_FETCH_FORCE_ENABLED: when true, delete and re-clone existing plugin dirs (default: false)
# Safety:
# - When PLUGIN_FETCH_FORCE_ENABLED=true and PLUGIN_FETCH_DRY_RUN_ENABLED=false, this removes the plugin directory.
plugin_fetch_if_missing_from_entry() {
  typeset entry="$1"
  typeset -a parts=()
  typeset plugin_name='' git_url=''

  parts=("${(@s/::/)entry}")
  plugin_name="${parts[1]}"
  plugin_name="${plugin_name#"${plugin_name%%[![:space:]]*}"}"
  plugin_name="${plugin_name%"${plugin_name##*[![:space:]]}"}"
  if [[ -z "$plugin_name" || "$plugin_name" == '.' || "$plugin_name" == '..' || "$plugin_name" == *[^A-Za-z0-9._-]* ]]; then
    print -u2 -r -- "plugin_fetch_if_missing_from_entry: invalid plugin id in entry: ${entry:-<empty>}"
    return 1
  fi

  for part in "${parts[@]:2}"; do
    if [[ "$part" == git=* ]]; then
      git_url="${part#git=}"
    fi
  done

  typeset plugin_path="$ZSH_PLUGINS_DIR/$plugin_name"

  if (( $+functions[zsh_env::is_true] )) \
      && zsh_env::is_true "${PLUGIN_FETCH_FORCE_ENABLED-}" "PLUGIN_FETCH_FORCE_ENABLED" \
      && [[ -d "$plugin_path" ]]; then
    printf "💥 Forcing re-clone: %s\n" "$plugin_name"
    if (( ! $+functions[zsh_env::is_true] )) || ! zsh_env::is_true "${PLUGIN_FETCH_DRY_RUN_ENABLED-}" "PLUGIN_FETCH_DRY_RUN_ENABLED"; then
      rm -rf "$plugin_path"
    fi
  fi

  if [[ -d "$plugin_path" ]]; then
    return 0
  fi

  if [[ -n "$git_url" ]]; then
    printf "🌐 Cloning %s from %s\n" "$plugin_name" "$git_url"
    if (( ! $+functions[zsh_env::is_true] )) || ! zsh_env::is_true "${PLUGIN_FETCH_DRY_RUN_ENABLED-}" "PLUGIN_FETCH_DRY_RUN_ENABLED"; then
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

# plugin_update_all
# Update all git plugin repos under $ZSH_PLUGINS_DIR (fast-forward only).
# Usage: plugin_update_all
# Env:
# - ZSH_PLUGINS_DIR: plugin base directory (default: $ZDOTDIR/plugins)
# - PLUGIN_FETCH_DRY_RUN_ENABLED: when true, do not modify repos; print intended commands (default: false)
plugin_update_all() {
  emulate -L zsh
  setopt pipe_fail err_return nounset null_glob

  typeset plugins_dir=''
  typeset plugin_name='' before='' after='' short_after='' output=''
  plugins_dir="$ZSH_PLUGINS_DIR"
  [[ -d "$plugins_dir" ]] || return 0

  printf "🔄 Updating plugins in: %s\n\n" "$plugins_dir"
  for dir in "$plugins_dir"/*(/N); do
    [[ -d "$dir/.git" ]] || continue
    plugin_name="${dir##*/}"
    printf "🔧 Updating %s ...\n" "$plugin_name"

    if (( $+functions[zsh_env::is_true] )) && zsh_env::is_true "${PLUGIN_FETCH_DRY_RUN_ENABLED-}" "PLUGIN_FETCH_DRY_RUN_ENABLED"; then
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

# plugin_maybe_auto_update
# Auto-update plugins based on the timestamp in $PLUGIN_UPDATE_FILE.
# Usage: plugin_maybe_auto_update
# Notes:
# - Calls plugin_update_all and writes a new timestamp when an update is performed.
# - Current threshold: 7 days (see implementation).
plugin_maybe_auto_update() {
  typeset now_epoch='' last_epoch=''

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

# plugin_print_status
# Print plugin auto-update status based on $PLUGIN_UPDATE_FILE.
# Usage: plugin_print_status
plugin_print_status() {
  emulate -L zsh
  setopt pipe_fail

  typeset now_epoch=0 last_epoch=0 days_ago=0 days_left=0
  typeset last_date=''

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
