# safe_unalias: Safely remove one or more aliases without causing errors
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
  if [[ "$1" == "-v" ]]; then
    verbose=true
    shift
  fi

  for name in "$@"; do
    if alias "$name" &>/dev/null; then
      $verbose && echo "🔁 Unaliasing $name"
      unalias "$name"
    fi
  done
}

# Clipboard abstraction (macOS pbpaste, Linux xclip/xsel)
get_clipboard() {
  if command -v pbpaste >/dev/null 2>&1; then
    pbpaste
  elif command -v xclip >/dev/null 2>&1; then
    xclip -selection clipboard -o
  elif command -v xsel >/dev/null 2>&1; then
    xsel --clipboard --output
  else
    echo "❌ No clipboard tool found (requires pbpaste, xclip, or xsel)" >&2
    return 1
  fi
}

# Clipboard abstraction for writing (macOS pbcopy, Linux xclip/xsel)
set_clipboard() {
  if command -v pbcopy >/dev/null 2>&1; then
    pbcopy
  elif command -v xclip >/dev/null 2>&1; then
    xclip -selection clipboard -i
  elif command -v xsel >/dev/null 2>&1; then
    xsel --clipboard --input
  else
    echo "❌ No clipboard tool found (requires pbcopy, xclip, or xsel)" >&2
    return 1
  fi
}
