# ───────────────────────────────────────────────────────
# Aliases and Unalias
# ────────────────────────────────────────────────────────
if command -v safe_unalias >/dev/null; then
  safe_unalias \
    fd-files fd-dirs fdf fdd \
    bat-view batp \
    kp kpid \
    reload execz zz zsh-reload zsh-restart \
    histflush history-flush \
    edit-zsh y \
    cheat weather \
    bff his
fi

# Legacy cleanup (functions removed from shell-tools.zsh).
for _su_fn in bat-all zdef fsearch fzf-history-wrapper; do
  (( $+functions[$_su_fn] )) && unfunction "$_su_fn"
done
unset _su_fn

# ────────────────────────────────────────────────────────
# fd helpers (file and directory search)
# ────────────────────────────────────────────────────────

# fd-files: Find files via fd (includes hidden; excludes .git).
# Usage: fd-files [fd args...]
alias fd-files='fd --type f --hidden --follow --exclude .git'

# fd-dirs: Find directories via fd (includes hidden; excludes .git).
# Usage: fd-dirs [fd args...]
alias fd-dirs='fd --type d --hidden --follow --exclude .git'

# fdf: Alias of fd-files.
# Usage: fdf [fd args...]
alias fdf='fd-files'

# fdd: Alias of fd-dirs.
# Usage: fdd [fd args...]
alias fdd='fd-dirs'

# ────────────────────────────────────────────────────────
# Process helpers
# ────────────────────────────────────────────────────────

# _su_kill_do <signal> <pid...>
# Validate and send a signal to one or more PIDs (deduped).
# Usage: _su_kill_do <signal> <pid...>
_su_kill_do() {
  emulate -L zsh
  setopt localoptions err_return

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

# ────────────────────────────────────────────────────────
# Shell session helpers
# ────────────────────────────────────────────────────────

# zsh-reload
# Reload the Zsh environment by re-sourcing bootstrap/bootstrap.zsh.
# Usage: zsh-reload
zsh-reload() {
  emulate -L zsh
  # NOTE: Do NOT enable `err_return` here.
  # The bootstrap/plugin loader is best-effort and may intentionally return non-zero.
  # Enabling `err_return` could abort the reload prematurely.

  print -r -- ""
  print -r -- "🔁 Reloading bootstrap/bootstrap.zsh..."
  print -r -- "💡 For major changes, consider running: zsh-restart"
  print -r -- ""

  if ! source "$ZDOTDIR/bootstrap/bootstrap.zsh"; then
    print -u2 -r -- "❌ Failed to reload Zsh environment"
    print -r -- ""
    return 1
  fi
}

# reload: Alias of zsh-reload.
# Usage: reload
alias reload='zsh-reload'

# zsh-restart
# Restart the current shell session (exec zsh).
# Usage: zsh-restart
# Notes:
# - Replaces the current process; unsaved shell state is lost.
zsh-restart() {
  emulate -L zsh
  setopt localoptions err_return

  print -r -- ""
  print -r -- "🚪 Restarting Zsh shell (exec zsh)..."
  print -r -- "🧼 This will start a clean session using current configs."
  print -r -- ""
  exec zsh
}

# execz: Alias of zsh-restart.
# Usage: execz
alias execz='zsh-restart'

# zz: Alias of zsh-restart.
# Usage: zz
alias zz='zsh-restart'

# history-flush
# Flush in-memory history to the history file.
# Usage: history-flush
history-flush() {
  emulate -L zsh
  setopt localoptions err_return

  fc -AI # Append memory history, re-read file
}

# histflush: Alias of history-flush.
# Usage: histflush
alias histflush='history-flush'

# edit-zsh
# Open the Zsh config directory in VS Code, then return to the current directory.
# Usage: edit-zsh
edit-zsh() {
  emulate -L zsh
  setopt localoptions err_return

  typeset cwd
  cwd="$(pwd)"

  code "$ZDOTDIR"
  builtin cd -- "$cwd" >/dev/null
}

# y [dir] [yazi args...]
# Launch yazi and change to the last visited directory on exit.
# Usage: y [dir] [yazi args...]
# Notes:
# - If the first argument does not start with `-`, it is treated as a zoxide target.
y() {
  emulate -L zsh
  setopt localoptions pipe_fail err_return

  if ! command -v yazi >/dev/null 2>&1; then
    print -u2 -r -- "❌ yazi not found"
    return 127
  fi

  # Detect directory alias/keyword as the first argument (non‑flag)
  if [[ -n "$1" && "$1" != -* ]]; then
    typeset target="$1"
    shift
    if (( $+functions[__zoxide_z] )); then
      __zoxide_z "$target"
    else
      builtin cd -- "$target" 2>/dev/null || {
        print -u2 -r -- "❌ Unable to resolve directory: $target"
        return 1
      }
    fi
  fi

  # Launch yazi and persist the last visited directory on exit
  typeset tmp cwd
  tmp="$(mktemp -t 'yazi-cwd.XXXXXX')" || return 1
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(<"$tmp")" && [[ -n "$cwd" && "$cwd" != "$PWD" ]]; then
    builtin cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}

# ────────────────────────────────────────────────────────
# Network helpers (curl-based)
# ────────────────────────────────────────────────────────

# cheat <query>
# Query cheat.sh via curl.
# Usage: cheat <query>
# Notes:
# - Requires network access.
cheat() {
  emulate -L zsh
  setopt localoptions err_return

  if (( $# == 0 )); then
    print -u2 -r -- "Usage: cheat <query>"
    return 2
  fi

  typeset query="${(j:+:)@}"
  curl -s -- "https://cheat.sh/${query}"
}

# weather [location]
# Print weather information from wttr.in.
# Usage: weather [location]
# Notes:
# - Requires network access.
weather() {
  emulate -L zsh
  setopt localoptions err_return

  if ! command -v curl >/dev/null 2>&1; then
    print -u2 -r -- "❌ curl not found"
    return 127
  fi

  typeset location="${(j:+:)@}"
  if [[ -n "$location" ]]; then
    curl -s -- "https://wttr.in/${location}"
  else
    curl -s -- "https://wttr.in"
  fi
}
