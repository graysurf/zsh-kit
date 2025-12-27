# ───────────────────────────────────────────────────────
# Aliases and Unalias
# ────────────────────────────────────────────────────────
if command -v safe_unalias >/dev/null; then
  safe_unalias \
    vi cd edit-zsh y \
    fdf fdd cat batp bat-all bff \
    fsearch zdef cheat kp kpid \
    reload execz zz histflush \
    history his fzf-history-wrapper
fi

# ────────────────────────────────────────────────────────
# Basic editors & overrides
# ────────────────────────────────────────────────────────

export EDITOR="nvim"
alias vi=$EDITOR

# Override 'cd' to auto-list
cd() {
  builtin cd "$@" && eza -alh --icons --group-directories-first --time-style=iso
}

# ────────────────────────────────────────────────────────
# fd aliases (file and directory search)
# ────────────────────────────────────────────────────────

alias fdf='fd --type f --hidden --follow --exclude .git'
alias fdd='fd --type d --hidden --follow --exclude .git'

# ────────────────────────────────────────────────────────
# bat aliases (syntax-highlighted file viewing)
# ────────────────────────────────────────────────────────

# Replace cat with bat for plain, no-pager display
alias cat='bat --style=plain --pager=never'

# Pretty bat view: line numbers, paging, theme
alias batp='bat --style=numbers --paging=always'

# ────────────────────────────────────────────────────────
# fd + bat + fzf integration functions
# ────────────────────────────────────────────────────────

# bff: select and preview multiple files using bat
bat-all() {
  fdf | fzf -m --preview 'bat --color=always --style=numbers {}' |
    xargs -r bat --style=numbers --paging=always
}
alias bff='bat-all'

# Show current shell aliases, functions, and environment variables for debugging
zdef() {
  {
  printf "🔗 Aliases:\n"
      alias | sed 's/^/  /'

  printf "\n🔧 Functions:\n"
      for fn in ${(k)functions}; do
  printf "  $fn\n"
      done

  printf "\n🌱 Environment Variables:\n"
      printenv | sort | sed 's/^/  /'
    } | fzf --ansi --header="🔍 Zsh Definitions (aliases, functions, env)" --preview-window=wrap
}

# fsearch: search for file content and preview with bat + ripgrep
fsearch() {
  typeset query="$1"
  fd --type f --hidden --exclude .git |
    fzf --preview "bat --color=always --style=numbers {} | rg --color=always --context 5 '$query'" \
        --bind=ctrl-j:preview-down \
        --bind=ctrl-k:preview-up 
}

# ────────────────────────────────────────────────────────
# Shared helpers (shell-utils)
# ────────────────────────────────────────────────────────

# Execute kill with dedupe and basic validation.
# Usage: _su_kill_do <signal> <pid...>
_su_kill_do() {
  emulate -L zsh
  setopt localoptions

  typeset -i signal
  signal=${1:-15}
  shift

  typeset -a pids
  pids=($@)
  # Deduplicate numeric PIDs only
  typeset -a filtered=()
  local pid
  for pid in ${pids[@]}; do
    [[ "$pid" == <-> ]] && filtered+=("$pid")
  done
  filtered=(${(u)filtered})

  if (( ${#filtered} == 0 )); then
    print -r -- "ℹ️  No valid PIDs provided"
    return 2
  fi

  kill -${signal} -- ${^filtered}
}

# ────────────────────────────────────────────────────────
# kill-port: Kill process(es) listening on a TCP/UDP port
# Usage: kill-port [-9] <port>
# - Default sends SIGTERM (15). Use -9 to send SIGKILL.
# - macOS friendly (uses lsof); works wherever lsof provides -t.
# ────────────────────────────────────────────────────────
kill-port() {
  emulate -L zsh
  setopt localoptions pipe_fail

  typeset -i signal=15
  if [[ "$1" == "-9" ]]; then
    signal=9
    shift
  fi

  typeset port="$1"
  if [[ -z "$port" || ! $port == <-> ]]; then
    print -u2 -r -- "Usage: kill-port [-9] <port>"
    return 2
  fi

  typeset -a pids=()
  # TCP listeners
  pids+=(${(f)$(lsof -nP -iTCP:$port -sTCP:LISTEN -t 2>/dev/null)})
  # UDP consumers (no LISTEN state for UDP)
  pids+=(${(f)$(lsof -nP -iUDP:$port -t 2>/dev/null)})
  # unique
  pids=(${(u)pids})

  if (( ${#pids} == 0 )); then
    print -r -- "ℹ️  No process found on port $port"
    return 0
  fi

  print -r -- "☠️  Killing (SIG${signal}) PIDs on port $port: ${pids[*]}"
  _su_kill_do ${signal} ${^pids}
}

alias kp='kill-port'

# ────────────────────────────────────────────────────────
# kill-process: Kill one or more PIDs
# Usage: kill-process [-9] <pid> [pid...]
# - Default sends SIGTERM (15). Use -9 to send SIGKILL.
# - Validates that all provided PIDs are numeric.
# ────────────────────────────────────────────────────────
kill-process() {
  emulate -L zsh
  setopt localoptions pipe_fail

  typeset -i signal=15
  if [[ "$1" == "-9" ]]; then
    signal=9
    shift
  fi

  if (( $# < 1 )); then
    print -u2 -r -- "Usage: kill-process [-9] <pid> [pid...]"
    return 2
  fi

  typeset -a pids=()
  typeset pid
  for pid in "$@"; do
    if [[ "$pid" == <-> ]]; then
      pids+=("$pid")
    else
      print -u2 -r -- "❌ Invalid PID: $pid"
      return 2
    fi
  done

  # Execute kill with shared helper
  print -r -- "☠️  Killing (SIG${signal}) PID(s): ${pids[*]}"
  _su_kill_do ${signal} ${^pids}
}

alias kpid='kill-process'

# ────────────────────────────────────────────────────────
# Reload the Zsh environment via bootstrap init
# Use for small config changes without restarting shell
# ────────────────────────────────────────────────────────
reload() {
  printf "\n"
  printf "🔁 Reloading bootstrap/bootstrap.zsh...\n"
  printf "💡 For major changes, consider running: execz\n\n"

  if ! source "$ZDOTDIR/bootstrap/bootstrap.zsh"; then
    printf "❌ Failed to reload Zsh environment\n\n"
  fi
}

# ────────────────────────────────────────────────────────
# Restart shell completely with a fresh session
# Useful after modifying core loader, plugin system, etc.
# ────────────────────────────────────────────────────────
execz() {
  printf "\n🚪 Restarting Zsh shell (exec zsh)...\n"
  printf "🧼 This will start a clean session using current configs.\n\n"
    exec zsh
}

alias zz='execz'

# ────────────────────────────────────────────────────────
# Force flush memory history to file
# reload latest history entries
# ────────────────────────────────────────────────────────
histflush() {
  fc -AI  # Append memory history, re-read file
}

# ────────────────────────────────────────────────────────
# Override `history` to launch fzf-history interactively when called with no arguments.
# Falls back to the original builtin `history` when arguments are passed (e.g. -d, -c, etc).
# ────────────────────────────────────────────────────────
alias history='fzf-history-wrapper'
alias his='fzf-history-wrapper'

fzf-history-wrapper() {
  if [[ "$1" == "" ]]; then
    # Fuzzy search command history and execute selected entry
    fzf-history
  else
    builtin history "$@"
  fi
}

# ────────────────────────────────────────────────────────
# Open your Zsh config directory in VSCode
# ────────────────────────────────────────────────────────
edit-zsh() {
  typeset cwd="$(pwd)"
  code "$ZDOTDIR"
  cd "$cwd" >/dev/null
}

# ────────────────────────────────────────────────────────
# Fuzzy cd using Yazi, then jump to selected directory
# Wrapper: `y <dir>` jumps to <dir> via zoxide first, then launches yazi.
# If the first argument begins with a dash (`-`) it is treated as a yazi flag.
# ────────────────────────────────────────────────────────
y () {
  # Detect directory alias/keyword as the first argument (non‑flag)
  if [[ -n "$1" && "$1" != -* ]]; then
    local target="$1"
    shift
    __zoxide_z "$target"
  fi

  # Launch yazi and persist the last visited directory on exit
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(<"$tmp")" && [[ -n "$cwd" && "$cwd" != "$PWD" ]]; then
    builtin cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}

# ────────────────────────────────────────────────────────
# Query cheat.sh (curl-based CLI cheatsheets)
# ────────────────────────────────────────────────────────
cheat() {
  curl -s cheat.sh/"$@"
}
