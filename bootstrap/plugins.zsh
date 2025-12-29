# ──────────────────────────────
# Manual Plugin Loader for Zsh-kit
# ──────────────────────────────

source "$ZSH_BOOTSTRAP_SCRIPT_DIR/plugin_fetcher.zsh"

typeset -f plugin_fetch_if_missing_from_entry &>/dev/null || {
  printf "❌ plugin_fetch_if_missing_from_entry not defined. Check bootstrap/plugin_fetcher.zsh\n"
  return 1
}

ZSH_PLUGINS_DIR="${ZSH_PLUGINS_DIR:-$ZDOTDIR/plugins}"
ZSH_PLUGIN_LIST_FILE="${ZSH_PLUGIN_LIST_FILE:-$ZDOTDIR/config/plugins.list}"

ZSH_PLUGINS=()
while IFS= read -r line; do
  [[ -z "$line" || "$line" == \#* ]] && continue
	ZSH_PLUGINS+=("$line")
done < "$ZSH_PLUGIN_LIST_FILE"

# load_plugin_entry <entry>
# Fetch (if needed) and source a plugin described by a `config/plugins.list` entry.
# Usage: load_plugin_entry <entry>
# Env:
# - ZSH_PLUGINS_DIR: plugin base directory (default: $ZDOTDIR/plugins)
# - ZSH_PLUGIN_LIST_FILE: plugin list file (default: $ZDOTDIR/config/plugins.list)
# Notes:
# - Supports `abbr` for the zsh-abbr plugin (adds completions + job queue).
# - Supports `KEY=VALUE` style extras via eval (trusted config only).
load_plugin_entry() {
	typeset entry="$1"
	typeset -a parts
	IFS='::' read -r -A parts <<< "$entry"

  typeset plugin_name="${parts[1]}"
  typeset main_file="${parts[2]:-${plugin_name}.plugin.zsh}"
  typeset extra="${parts[3]:-}"
  typeset git_url=""

  # look for git URL in the rest of the fields
  for part in "${parts[@]:3}"; do
    if [[ "$part" == git=* ]]; then
      git_url="${part#git=}"
    fi
  done

  typeset plugin_path="$ZSH_PLUGINS_DIR/$plugin_name"
  typeset full_path="$plugin_path/$main_file"

  # fetch if missing
  plugin_fetch_if_missing_from_entry "$entry"

  # try to load
  if [[ -f "$full_path" ]]; then
    if [[ "$extra" == "abbr" ]]; then
      fpath+=("$plugin_path/completions")
      fpath+=("$plugin_path/zsh-job-queue")
      source "$plugin_path/zsh-job-queue/zsh-job-queue.plugin.zsh"
    fi

    # also handle environment variable style extra
    if [[ "$extra" == *=* ]]; then
      eval "$extra"
    fi

    source "$full_path"
  fi

  return 0
}

# load them all
for plugin_entry in "${ZSH_PLUGINS[@]}"; do
  load_plugin_entry "$plugin_entry"
done

# auto-updating Zsh plugins
plugin_maybe_auto_update
