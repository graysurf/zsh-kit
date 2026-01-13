# safe_unalias [-v] <name...>
# Safely remove one or more aliases without causing errors.
#
# This utility function checks whether each given name is an existing alias,
# and only unaliases it if it exists. This avoids "no such hash table element"
# errors when running scripts that are sourced multiple times or across environments.
#
# It also supports an optional `-v` flag to enable verbose output for debugging.
#
# Usage:
#   safe_unalias foo bar       # Silently unalias 'foo' and 'bar' if they exist
#   safe_unalias -v foo bar    # Verbosely unalias 'foo' and 'bar'
#
# Notes:
# - This function is meant to be defined early in the shell environment,
#   so it can be reused safely in all scripts.
# - It only affects aliases (not functions or commands).
safe_unalias() {
  typeset verbose=false
  typeset first_arg="${1-}"

  if [[ "$first_arg" == "-v" ]]; then
    verbose=true
    shift
  fi

  for name in "$@"; do
    if alias "$name" &>/dev/null; then
      $verbose && printf "🔁 Unaliasing %s\n" "$name"
      unalias "$name"
    fi
  done

  return 0
}

# get_clipboard
# Read clipboard contents and print to stdout.
# Usage: get_clipboard
# Notes:
# - Requires pbpaste (macOS) or xclip/xsel (Linux).
get_clipboard() {
  if command -v pbpaste >/dev/null 2>&1; then
    pbpaste
  elif command -v xclip >/dev/null 2>&1; then
    xclip -selection clipboard -o
  elif command -v xsel >/dev/null 2>&1; then
    xsel --clipboard --output
  else
    printf "❌ No clipboard tool found (requires pbpaste, xclip, or xsel)\n" >&2
    return 1
  fi
}

# set_clipboard
# Read stdin and write it to the system clipboard.
# Usage: <command> | set_clipboard
# Notes:
# - Requires pbcopy (macOS) or xclip/xsel (Linux).
set_clipboard() {
  if command -v pbcopy >/dev/null 2>&1; then
    pbcopy
  elif command -v xclip >/dev/null 2>&1; then
    xclip -selection clipboard -i
  elif command -v xsel >/dev/null 2>&1; then
    xsel --clipboard --input
  else
    printf "❌ No clipboard tool found (requires pbcopy, xclip, or xsel)\n" >&2
    return 1
  fi
}

# progress_bar::load
# Load the progress bar implementation (scripts/progress-bar.zsh) on demand.
# Usage: progress_bar::load
# Notes:
# - This is a bootstrap-time shim so cached CLI wrappers (which bundle 00-preload.zsh) can use it.
# - Returns non-zero when the module file is missing/unreadable.
progress_bar::load() {
  emulate -L zsh

  if (( ${+functions[_progress_bar::build_bar]} )); then
    typeset -g _ZSH_PROGRESS_BAR_LOADED=1
    return 0
  fi

  typeset zdotdir="${ZDOTDIR:-$HOME/.config/zsh}"
  typeset script_dir="${ZSH_SCRIPT_DIR:-$zdotdir/scripts}"
  typeset target="$script_dir/progress-bar.zsh"

  [[ -r "$target" ]] || return 1
  source "$target" || return 1

  (( ${+functions[_progress_bar::build_bar]} )) && return 0
  return 1
}

# progress_bar::init
# Bootstrap shim for progress_bar::init (determinate progress bar).
# Usage: progress_bar::init <id> --prefix <text> --total <n> [--width <n>] [--head-len <n>] [--fd <n>] [--enabled|--disabled]
progress_bar::init() { progress_bar::load || return $?; progress_bar::init "$@"; }

# progress_bar::update
# Bootstrap shim for progress_bar::update (determinate progress bar).
# Usage: progress_bar::update <id> <current> [--suffix <text>] [--force]
progress_bar::update() { progress_bar::load || return $?; progress_bar::update "$@"; }

# progress_bar::finish
# Bootstrap shim for progress_bar::finish (determinate progress bar).
# Usage: progress_bar::finish <id> [--suffix <text>]
progress_bar::finish() { progress_bar::load || return $?; progress_bar::finish "$@"; }

# progress_bar::init_indeterminate
# Bootstrap shim for progress_bar::init_indeterminate (indeterminate progress bar).
# Usage: progress_bar::init_indeterminate <id> --prefix <text> [--width <n>] [--head-len <n>] [--fd <n>] [--enabled|--disabled]
progress_bar::init_indeterminate() { progress_bar::load || return $?; progress_bar::init_indeterminate "$@"; }

# progress_bar::tick
# Bootstrap shim for progress_bar::tick (advance indeterminate progress bar).
# Usage: progress_bar::tick <id> [--suffix <text>] [--force]
progress_bar::tick() { progress_bar::load || return $?; progress_bar::tick "$@"; }

# progress_bar::stop
# Bootstrap shim for progress_bar::stop (clear indeterminate progress bar line).
# Usage: progress_bar::stop <id>
progress_bar::stop() { progress_bar::load || return $?; progress_bar::stop "$@"; }
