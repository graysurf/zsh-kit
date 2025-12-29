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

# vi: Alias to `$EDITOR`.
# Usage: vi [args...]
alias vi=$EDITOR

# cd [path]
# Change directory then list contents via eza.
# Usage: cd [path]
# Notes:
# - Overrides builtin `cd` in interactive shells.
cd() {
  builtin cd "$@" && eza -alh --icons --group-directories-first --time-style=iso
}

# ────────────────────────────────────────────────────────
# fd aliases (file and directory search)
# ────────────────────────────────────────────────────────

# fdf: Find files via fd (includes hidden; excludes .git).
# Usage: fdf [fd args...]
alias fdf='fd --type f --hidden --follow --exclude .git'

# fdd: Find directories via fd (includes hidden; excludes .git).
# Usage: fdd [fd args...]
alias fdd='fd --type d --hidden --follow --exclude .git'

# ────────────────────────────────────────────────────────
# bat aliases (syntax-highlighted file viewing)
# ────────────────────────────────────────────────────────

# cat: Alias to bat (plain output; no pager).
# Usage: cat <path...>
# Notes:
# - Overrides `cat` in interactive shells.
alias cat='bat --style=plain --pager=never'

# batp: View files with bat (line numbers; paging enabled).
# Usage: batp <path...>
alias batp='bat --style=numbers --paging=always'

# ────────────────────────────────────────────────────────
# fd + bat + fzf integration functions
# ────────────────────────────────────────────────────────

# bat-all
# Select one or more files via fzf and preview them with bat.
# Usage: bat-all
# Notes:
# - Requires `fd`, `fzf`, and `bat`.
bat-all() {
  fdf | fzf -m --preview 'bat --color=always --style=numbers {}' |
    xargs -r bat --style=numbers --paging=always
}

# bff: Alias of bat-all.
# Usage: bff
alias bff='bat-all'

# zdef
# Browse aliases, functions, and environment variables via fzf.
# Usage: zdef
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

# fsearch <query>
# Fuzzy-pick a file and preview grep context for the query.
# Usage: fsearch <query>
# Notes:
# - Requires `fd`, `fzf`, `bat`, and `rg`.
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

# _su_kill_do <signal> <pid...>
# Validate and send a signal to one or more PIDs (deduped).
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

# kill-port [-9] <port>
# Kill process(es) listening on a TCP/UDP port.
# Usage: kill-port [-9] <port>
# Options:
# - -9: send SIGKILL (9) instead of SIGTERM (15).
# Notes:
# - Uses `lsof` to resolve PIDs (TCP LISTEN + UDP).
# Safety:
# - Killing processes may interrupt services and cause data loss.
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

# kp: Alias of kill-port.
# Usage: kp [-9] <port>
alias kp='kill-port'

# kill-process [-9] <pid> [pid...]
# Kill one or more PIDs.
# Usage: kill-process [-9] <pid> [pid...]
# Options:
# - -9: send SIGKILL (9) instead of SIGTERM (15).
# Safety:
# - Killing processes may interrupt services and cause data loss.
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

# kpid: Alias of kill-process.
# Usage: kpid [-9] <pid> [pid...]
alias kpid='kill-process'

# reload
# Reload the Zsh environment by re-sourcing bootstrap/bootstrap.zsh.
# Usage: reload
reload() {
  printf "\n"
  printf "🔁 Reloading bootstrap/bootstrap.zsh...\n"
  printf "💡 For major changes, consider running: execz\n\n"

  if ! source "$ZDOTDIR/bootstrap/bootstrap.zsh"; then
    printf "❌ Failed to reload Zsh environment\n\n"
  fi
}

# execz
# Restart the current shell session (exec zsh).
# Usage: execz
# Notes:
# - Replaces the current process; unsaved shell state is lost.
execz() {
  printf "\n🚪 Restarting Zsh shell (exec zsh)...\n"
  printf "🧼 This will start a clean session using current configs.\n\n"
    exec zsh
}

# zz: Alias of execz.
# Usage: zz
alias zz='execz'

# histflush
# Flush in-memory history to the history file.
# Usage: histflush
histflush() {
  fc -AI  # Append memory history, re-read file
}

# history: Alias of fzf-history-wrapper.
# Usage: history [history args...]
# Notes:
# - With no arguments, launches fzf-history; otherwise falls back to builtin `history`.
alias history='fzf-history-wrapper'

# his: Alias of fzf-history-wrapper.
# Usage: his [history args...]
alias his='fzf-history-wrapper'

# fzf-history-wrapper [history args...]
# Fuzzy-search shell history when called with no arguments.
# Usage: fzf-history-wrapper [history args...]
fzf-history-wrapper() {
  if [[ "$1" == "" ]]; then
    # Fuzzy search command history and execute selected entry
    fzf-history
  else
    builtin history "$@"
  fi
}

# edit-zsh
# Open the Zsh config directory in VS Code, then return to the current directory.
# Usage: edit-zsh
edit-zsh() {
  typeset cwd="$(pwd)"
  code "$ZDOTDIR"
  cd "$cwd" >/dev/null
}

# y [dir] [yazi args...]
# Launch yazi and change to the last visited directory on exit.
# Usage: y [dir] [yazi args...]
# Notes:
# - If the first argument does not start with `-`, it is treated as a zoxide target.
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

# cheat <query>
# Query cheat.sh via curl.
# Usage: cheat <query>
# Notes:
# - Requires network access.
cheat() {
  curl -s cheat.sh/"$@"
}
