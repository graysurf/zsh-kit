# ────────────────────────────────────────────────────────
# Aliases and Unalias
# ────────────────────────────────────────────────────────
if command -v safe_unalias >/dev/null; then
  safe_unalias ft fzf-process fzf-env fzf-port fp fgs gg fgc ff fv
fi

# ft
# Alias of `fzf-tools`.
# Usage: ft <subcommand> [args...]
alias ft='fzf-tools'

# fgs
# Alias of `fzf-git-status`.
# Usage: fgs
alias fgs='fzf-git-status'

# gg
# Alias of `fzf-git-status`.
# Usage: gg
alias gg='fzf-git-status'

# fgc
# Alias of `fzf-git-commit`.
# Usage: fgc [--snapshot] [query]
alias fgc='fzf-git-commit'

# ff
# Alias of `fzf-file`.
# Usage: ff
alias ff='fzf-file'

# fv
# Alias of `fzf-file --vscode`.
# Usage: fv
alias fv='fzf-file --vscode'

# fp
# Alias of `fzf-port`.
# Usage: fp [-k|--kill] [-9|--force]
alias fp='fzf-port'

# ────────────────────────────────────────────────────────
# fzf utilities
# ────────────────────────────────────────────────────────

# _fzf_confirm
# Prompt for confirmation and return non-zero on decline.
# Usage: _fzf_confirm <printf_format> [args...]
# Notes:
# - Reads from stdin; returns success only when the user answers "y" (case-insensitive).
_fzf_confirm() {
  local prompt="${1-}"
  [[ -z "$prompt" ]] && return 1
  shift

  printf "$prompt" "$@"

  local confirm=''
  read -r confirm
  [[ "$confirm" != [yY] ]] && printf "🚫 Aborted.\n" && return 1
  return 0
}

# _fzf_script_root
# Print the scripts root directory for lazy-loading.
# Usage: _fzf_script_root
# Notes:
# - Prefers `$ZSH_SCRIPT_DIR`, then `$ZDOTDIR/scripts`, then `$HOME/.config/zsh/scripts`.
_fzf_script_root() {
  local script_root=''
  if [[ -n "${ZSH_SCRIPT_DIR-}" ]]; then
    script_root="$ZSH_SCRIPT_DIR"
  elif [[ -n "${ZDOTDIR-}" ]]; then
    script_root="$ZDOTDIR/scripts"
  else
    script_root="$HOME/.config/zsh/scripts"
  fi

  print -r -- "$script_root"
}

# _fzf_ensure_git_utils
# Ensure git utility helpers are loaded (best-effort).
# Usage: _fzf_ensure_git_utils
# Notes:
# - Lazily sources `scripts/git/tools/git-utils.zsh` when `get_commit_hash` is missing.
_fzf_ensure_git_utils() {
  if typeset -f get_commit_hash >/dev/null 2>&1; then
    return 0
  fi

  local script_root=''
  script_root="$(_fzf_script_root)"

  [[ -f "$script_root/git/tools/git-utils.zsh" ]] && source "$script_root/git/tools/git-utils.zsh"
  if ! typeset -f get_commit_hash >/dev/null 2>&1; then
    printf "❌ get_commit_hash is unavailable. Ensure git utils are loaded.\n" >&2
    return 1
  fi

  return 0
}

# _fzf_ensure_git_scope
# Ensure git-scope helpers are loaded (best-effort).
# Usage: _fzf_ensure_git_scope
# Notes:
# - Lazily sources `scripts/git/git-scope.zsh` when `_git_scope_kind_color` is missing.
_fzf_ensure_git_scope() {
  if typeset -f _git_scope_kind_color >/dev/null 2>&1; then
    return 0
  fi

  local script_root=''
  script_root="$(_fzf_script_root)"

  [[ -f "$script_root/git/git-scope.zsh" ]] && source "$script_root/git/git-scope.zsh"
  if ! typeset -f _git_scope_kind_color >/dev/null 2>&1; then
    printf "❌ _git_scope_kind_color is unavailable. Ensure git-scope is loaded.\n" >&2
    return 1
  fi

  return 0
}

# ────────────────────────────────────────────────────────
# Shared helpers for kill flow across process/port
# ────────────────────────────────────────────────────────

# _fzf_parse_kill_flags [-k|--kill] [-9|--force] [args...]
# Parse -k/--kill and -9/--force flags into globals.
# Usage: _fzf_parse_kill_flags [-k|--kill] [-9|--force] [args...]
# Output:
# - Sets `_fzf_kill_now`, `_fzf_force_kill`, and `_fzf_kill_rest` (remaining args).
_fzf_parse_kill_flags() {
  # Parses -k/--kill and -9/--force from args into globals
  _fzf_kill_now=false
  _fzf_force_kill=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -k|--kill)  _fzf_kill_now=true ;;
      -9|--force) _fzf_force_kill=true ;;
      *) break ;;
    esac
    shift
  done
  _fzf_kill_rest=("$@")
}

# _fzf_kill_flow <pids> <kill_now> <force_kill>
# Confirm and dispatch kill signals for one or more PIDs.
# Usage: _fzf_kill_flow <pids> <kill_now> <force_kill>
# Safety:
# - Uses `kill` / `kill -9` on selected PIDs.
_fzf_kill_flow() {
  # $1: whitespace-separated PIDs
  # $2: kill_now (true/false)
  # $3: force_kill (true/false)
  local pids="$1" kill_now="$2" force_kill="$3"
  [[ -z "$pids" ]] && return 0

  if $kill_now; then
    if $force_kill; then
      printf "☠️  Killing PID(s) with SIGKILL: %s\n" "$pids"
      print -r -- "$pids" | xargs kill -9
    else
      printf "☠️  Killing PID(s) with SIGTERM: %s\n" "$pids"
      print -r -- "$pids" | xargs kill
    fi
    return 0
  fi

  _fzf_confirm "Kill PID(s): %s? [y/N] " "$pids" || return 1

  printf "Force SIGKILL (-9)? [y/N] "
  local force=''
  read -r force
  if [[ "$force" == [yY] ]]; then
    printf "☠️  Killing PID(s) with SIGKILL: %s\n" "$pids"
    print -r -- "$pids" | xargs kill -9
  else
    printf "☠️  Killing PID(s) with SIGTERM: %s\n" "$pids"
    print -r -- "$pids" | xargs kill
  fi
}

# fzf-git-branch
# Browse and checkout branches.
# Usage: fzf-git-branch [query]
# Notes:
# - Shows recent branches; preview displays recent commit graph.
# - Confirms before `git checkout`.
fzf-git-branch() {
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    printf "❌ Not inside a Git repository. Aborting.\n" >&2
    return 1
  fi

  local query="$*"

  # List local branches, strip '* ' from current, but show it
  local selected=''
  selected=$(git branch --color=always --sort=-committerdate | \
    sed 's/^..//' | \
    fzf --ansi --reverse \
      --prompt="🌿 Branch > " \
      --query="$query" \
      --preview-window="right:60%:wrap" \
      --preview='
        branch=$(printf "%s\n" {} | sed "s/^[* ]*//")
        [[ -z "$branch" ]] && exit 0
        git log -n 100 --graph --color=always --decorate --abbrev-commit --date=iso-local \
         --pretty=format:"%C(bold #82aaff)%h%C(reset) %C(#ecc48d)%ad%C(reset) %C(#7fdbca)%an%C(reset)%C(auto)%d%C(reset) %C(#d6deeb)%s%C(reset)" "$branch"' \
  )
  [[ -z "$selected" ]] && return 1

  # Remove any leading '*' and spaces
  local branch=''
  branch=$(print -r -- "$selected" | sed 's/^[* ]*//')

  _fzf_confirm "🚚 Checkout to branch '%s'? [y/N] " "$branch" || return 1

  if git checkout "$branch"; then
    printf "✅ Checked out to %s\n" "$branch"
    return 0
  else
    printf "⚠️  Checkout to '%s' failed. Likely due to local changes or conflicts.\n" "$branch"
    return 1
  fi
}

# fzf-git-tag
# Browse and checkout tags.
# Usage: fzf-git-tag [query]
# Notes:
# - Lists tags (newest first); preview shows commit log for the tag.
# - Confirms before checking out the tag's commit.
fzf-git-tag() {
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    printf "❌ Not inside a Git repository. Aborting.\n" >&2
    return 1
  fi

  local query="$*"

  # List tags, sorted by most recent
  local selected=''
  selected=$(git tag --sort=-creatordate | \
    fzf --ansi --reverse \
      --prompt="🏷️  Tag > " \
      --query="$query" \
      --preview-window="right:60%:wrap" \
      --preview='
        tag=$(printf "%s\n" {} | sed "s/^[* ]*//")
        [[ -z "$tag" ]] && exit 0
        hash=$(git rev-parse --verify --quiet "${tag}^{commit}")
        [[ -z "$hash" ]] && printf "❌ Could not resolve tag to commit.\n" && exit 0
        git log -n 100 --graph --color=always --decorate --abbrev-commit --date=iso-local \
          --pretty=format:"%C(bold #82aaff)%h%C(reset) %C(#ecc48d)%ad%C(reset) %C(#7fdbca)%an%C(reset)%C(auto)%d%C(reset) %C(#d6deeb)%s%C(reset)" "$hash"
      ' \
  )
  [[ -z "$selected" ]] && return 1

  # Remove any leading '*' and spaces (shouldn't be present for tags, but for symmetry)
  local tag=''
  tag=$(print -r -- "$selected" | sed 's/^[* ]*//')

  # Pre-resolve tag to commit hash for preview and checkout
  _fzf_ensure_git_utils || return 1

  local hash=''
  hash=$(get_commit_hash "$tag" 2>/dev/null)
  if [[ -z "$hash" ]]; then
    printf "❌ Could not resolve tag '%s' to a commit hash.\n" "$tag"
    return 1
  fi

  _fzf_confirm "🚚 Checkout to tag '%s'? [y/N] " "$tag" || return 1

  if git checkout "$hash"; then
    printf "✅ Checked out to tag %s (commit %s)\n" "$tag" "$hash"
    return 0
  else
    printf "⚠️  Checkout to tag '%s' failed. Likely due to local changes or conflicts.\n" "$tag"
    return 1
  fi
}

# fzf-process [-k|--kill] [-9|--force]
# Browse processes and optionally kill them.
# Usage: fzf-process [-k|--kill] [-9|--force] [query]
# Notes:
# - Default: select rows → confirm kill → optional confirm SIGKILL (-9).
# - Flags: -k immediate kill (SIGTERM); add -9/--force for SIGKILL.
# - Multi-select supported. Preview shows CPU/MEM/PPID/start/time/cmd.
fzf-process() {
  # Flags: -k/--kill (no prompt), -9/--force (SIGKILL)
  _fzf_parse_kill_flags "$@"
  local kill_now="$_fzf_kill_now" force_kill="$_fzf_force_kill"
  local query="${(j: :)_fzf_kill_rest}"

  local line=''
  line=$(ps -eo user,pid,ppid,pcpu,pmem,stat,lstart,time,args | sed 1d | \
    fzf -m \
      --query="$query" \
      --preview-window='right:30%:wrap' \
      --preview='printf "%s\n" {} | awk '\''{
        uid  = $1;
        pid  = $2;
        ppid = $3;
        cpu  = $4;
        mem  = $5;
        stat = $6;
        start = sprintf("%s %s %s %s %s", $7, $8, $9, $10, $11);
        time = $12;
        cmd  = "";
        for (i=13; i<=NF; i++) cmd = cmd $i " ";

        printf "👤 UID\n%s\n\n", uid;
        printf "🔢 PID\n%s\n\n", pid;
        printf "👪 PPID\n%s\n\n", ppid;
        printf "🔥 CPU%%\n%s\n\n", cpu;
        printf "💾 MEM%%\n%s\n\n", mem;
        printf "📊 STAT\n%s\n\n", stat;
        printf "🕒 STARTED\n%s\n\n", start;
        printf "⌚ TIME\n%s\n\n", time;
        printf "💬 CMD\n%s\n", cmd;
      }'\''') || return

  local pids=''
  pids=$(print -r -- "$line" | awk '{print $2}')
  _fzf_kill_flow "$pids" "$kill_now" "$force_kill"
}

# fzf-port [-k|--kill] [-9|--force]
# Browse listening TCP ports and owning PIDs.
# Usage: fzf-port [-k|--kill] [-9|--force] [query]
# Notes:
# - Default: select rows → confirm kill owning PIDs → optional confirm SIGKILL.
# - Flags: -k immediate kill (SIGTERM); add -9/--force for SIGKILL.
# - Uses: lsof -nP -iTCP -sTCP:LISTEN; falls back to netstat (view-only).
# - Preview: protocol, addr:port, cmd, user, pid; plus lsof -p details.
fzf-port() {
  # Flags: -k/--kill (no prompt), -9/--force (SIGKILL)
  _fzf_parse_kill_flags "$@"
  local kill_now="$_fzf_kill_now" force_kill="$_fzf_force_kill"
  local query="${(j: :)_fzf_kill_rest}"

  # Prefer lsof for cross-platform listing (macOS/Linux). Show TCP LISTEN and UDP sockets.
  local line=''
  if command -v lsof >/dev/null 2>&1; then
    # Limit to TCP listeners explicitly (-iTCP) so state filter is reliable across platforms
    line=$(lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | sed 1d | \
      fzf -m \
        --prompt="🔌 Port > " \
        --query="$query" \
        --preview-window='right:50%:wrap' \
        --preview='printf "%s\n" {} | awk '\''{
          cmd = $1; pid = $2; user = $3;
          proto = "?"; name = "";
          for (i=1; i<=NF; i++) if ($i == "TCP" || $i == "UDP") { proto = $i; break }
          for (i=NF; i>=1; i--) if (index($i, ":") > 0) { name = $i; break }

          printf "🔭 PORT\n%s\n\n", name;
          printf "🌐 PROTO\n%s\n\n", proto;
          printf "📦 CMD\n%s\n\n", cmd;
          printf "👤 USER\n%s\n\n", user;
          printf "🔢 PID\n%s\n\n", pid;

          if (pid ~ /^[0-9]+$/) {
            printf "lsof -p %s\n\n", pid;
            system("lsof -nP -p " pid " 2>/dev/null | sed 1d | head -n 80");
          }
        }'\''') || return
  else
    # Fallback to netstat (BSD/macOS). Mark as view-only if no lsof.
    line=$(netstat -anv | \
      awk '/^(tcp|udp)/ {print}' | \
      fzf -m \
        --prompt="🔌 Port > " \
        --query="$query" \
        --preview-window='right:50%:wrap' \
        --preview='printf "%s\n\n(netstat view; no lsof PID info)\n" {}') || return
  fi

  # Extract PIDs (lsof output second column). Deduplicate.
  local pids=''
  pids=$(print -r -- "$line" | awk '{print $2}' | sort -u)
  _fzf_kill_flow "$pids" "$kill_now" "$force_kill"
}

# fzf-history-select
# Build and select shell history entries.
# Usage: fzf-history-select [query]
# Output:
# - Returns two lines (key, selected) for consumption by fzf-history.
# Notes:
# - Presents history with timestamps; preview shows formatted time + command.
fzf-history-select() {
  local default_query="${1-}"
  [[ -z "$default_query" ]] && default_query="${BUFFER:-}"

  iconv -f utf-8 -t utf-8 -c "$HISTFILE" |
  awk -F';' '
    /^:/ {
      if (NF < 2) next
      split($1, meta, ":")
      cmd = $2
      ts = meta[2]

      if (cmd ~ /^[[:space:]]*$/) next
      if (cmd ~ /^[[:cntrl:][:punct:][:space:]]*$/) next
      if (cmd ~ /[^[:print:]]/) next

      printf "%s | %4d | %s\n", ts, NR, cmd
    }
  ' | tac | fzf --ansi --reverse --height=50% \
         --query="$default_query" \
         --preview-window='right:50%:wrap' \
         --preview='ts=$(printf "%s\n" {} | cut -d"|" -f1 | sed -E "s/^[[:space:]]+//; s/[[:space:]]+$//"); \
fts=""; \
case "$ts" in (""|*[!0-9]*)) ;; (*) \
  if date -r "$ts" "+%Y-%m-%d %H:%M:%S" >/dev/null 2>&1; then \
    fts=$(date -r "$ts" "+%Y-%m-%d %H:%M:%S"); \
  elif date -d "@$ts" "+%Y-%m-%d %H:%M:%S" >/dev/null 2>&1; then \
    fts=$(date -d "@$ts" "+%Y-%m-%d %H:%M:%S"); \
  fi ;; \
esac; \
cmd=$(printf "%s\n" {} | cut -d"|" -f3- | sed -E "s/^[[:space:]]*(🖥️|🧪|🐧|🐳|🛠️)?[[:space:]]*//"); \
printf "🕒 %s\n\n%s" "$fts" "$cmd"' \
         --expect=enter
}

# fzf-history
# Search and execute a history command.
# Usage: fzf-history [query]
# Notes:
# - Uses fzf-history-select; executes selected command.
fzf-history() {
  local selected='' output='' cmd=''

  output="$(fzf-history-select "$*")"
  selected="$(printf "%s\n" "$output" | sed -n '2p')"

  cmd="$(printf "%s\n" "$selected" | cut -d'|' -f3- | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  cmd="$(printf "%s\n" "$cmd" | sed -E 's/^[[:space:]]*(🖥️|🧪|🐧|🐳|🛠️)?[[:space:]]*//')"

  [[ -n "$cmd" ]] && eval "$cmd"
}

# _fzf_file_select
# File selector with bat preview.
# Usage: _fzf_file_select [query]
# Notes:
# - Helper used by fzf-file.
_fzf_file_select() {
  typeset default_query="${1-}"
  fd --type f --hidden --follow --hidden --exclude .git --max-depth=${FZF_FILE_MAX_DEPTH:-10} 2>/dev/null |
    fzf --ansi \
        --query="$default_query" \
        --preview 'bat --color=always --style=numbers --line-range :100 {}'
}

# _fzf_find_git_root_upwards <start_dir> [max_depth]
# Find a git root directory (contains `.git`) within N parent levels.
# Usage: _fzf_find_git_root_upwards <start_dir> [max_depth]
# Output:
# - Prints the git root directory to stdout on success.
_fzf_find_git_root_upwards() {
  emulate -L zsh
  setopt err_return

  typeset dir="${1-}"
  typeset -i max_depth="${2:-5}"
  [[ -z "$dir" ]] && return 1

  dir="${dir:A}"

  typeset -i depth=0
  while (( depth <= max_depth )); do
    if [[ -e "$dir/.git" ]]; then
      print -r -- "$dir"
      return 0
    fi

    [[ "$dir" == "/" ]] && break
    dir="${dir:h}"
    (( ++depth ))
  done

  return 1
}

# _fzf_open_in_vscode_workspace <workspace_root> <file>
# Open a file in VSCode within a specific workspace root.
# Usage: _fzf_open_in_vscode_workspace <workspace_root> <file>
# Notes:
# - If the workspace root differs from the last opened one in this shell session, forces a new window.
_fzf_open_in_vscode_workspace() {
  emulate -L zsh
  setopt err_return

  typeset workspace_root="${1-}"
  typeset file="${2-}"
  typeset wait="${3-}"
  [[ -z "$workspace_root" || -z "$file" ]] && return 1

  if ! command -v code >/dev/null 2>&1; then
    print -u2 -r -- "❌ 'code' not found"
    return 127
  fi

  typeset workspace_path="${workspace_root:A}"
  typeset file_path="${file:A}"

  typeset -a code_args=()
  code_args=(--goto "$file_path")
  if [[ "$wait" == "--wait" ]]; then
    code_args=(--wait "${code_args[@]}")
  fi

  if [[ "${_FZF_VSCODE_LAST_GIT_ROOT-}" != "$workspace_path" ]]; then
    code_args=(--new-window "${code_args[@]}")
  fi
  typeset -g _FZF_VSCODE_LAST_GIT_ROOT="$workspace_path"
  code_args+=(-- "$workspace_path")

  code "${code_args[@]}"
}

# _fzf_open_in_vscode <file>
# Open a file in VSCode, preferring a Git root folder as workspace.
# Usage: _fzf_open_in_vscode <file>
# Notes:
# - Searches up to 5 parent dirs for `.git`; if found, opens that directory as the VSCode workspace root.
_fzf_open_in_vscode() {
  emulate -L zsh
  setopt err_return

  typeset file="${1-}"
  [[ -z "$file" ]] && return 1

  typeset file_path="${file:A}"
  typeset git_root=''
  git_root="$(_fzf_find_git_root_upwards "${file_path:h}" 5)" || git_root=""

  if [[ -n "$git_root" ]]; then
    _fzf_open_in_vscode_workspace "$git_root" "$file_path"
    return $?
  fi

  if ! command -v code >/dev/null 2>&1; then
    print -u2 -r -- "❌ 'code' not found"
    return 127
  fi

  code --goto "$file_path"
}

# _fzf_parse_open_with_flags [args...]
# Parse --vi / --vscode and return remaining args (query parts).
# Usage: _fzf_parse_open_with_flags [--vi|--vscode] [--] [query...]
# Output:
# - Sets `REPLY` to `vi` or `vscode` (default: `${FZF_FILE_OPEN_WITH:-vi}`).
# - Sets `reply` (array) to the remaining args after option parsing.
# Notes:
# - `--vi` and `--vscode` are mutually exclusive; flags override `FZF_FILE_OPEN_WITH`.
# - Unknown `--...` flags return status 2.
_fzf_parse_open_with_flags() {
  emulate -L zsh
  setopt err_return

  REPLY="${FZF_FILE_OPEN_WITH:-vi}"
  reply=()

  typeset seen_vi=false seen_vscode=false

  while (( $# > 0 )); do
    case "$1" in
      --vi)
        seen_vi=true
        REPLY="vi"
        ;;
      --vscode)
        seen_vscode=true
        REPLY="vscode"
        ;;
      --)
        shift
        reply=("$@")
        break
        ;;
      --*)
        print -u2 -r -- "❌ Unknown flag: $1"
        return 2
        ;;
      *)
        reply=("$@")
        break
        ;;
    esac
    shift
  done

  if $seen_vi && $seen_vscode; then
    print -u2 -r -- "❌ Flags are mutually exclusive: --vi and --vscode"
    return 2
  fi

  return 0
}

# _fzf_open_file <open_with> <file>
# Open a file with the chosen opener.
# Usage: _fzf_open_file <open_with> <file>
# Notes:
# - When `<open_with>` is `vscode`, uses `_fzf_open_in_vscode` and falls back to `vi` on failure.
_fzf_open_file() {
  emulate -L zsh
  setopt err_return

  typeset open_with="${1-}"
  typeset file="${2-}"

  [[ -z "$file" ]] && return 1

  if [[ "$open_with" == "vscode" ]]; then
    if ! _fzf_open_in_vscode "$file"; then
      print -u2 -r -- "❌ Failed to open in VSCode; falling back to vi"
      vi -- "$file"
    fi
    return 0
  fi

  vi -- "$file"
}

# fzf-file
# Pick a file and open it in an editor.
# Usage: fzf-file [--vi|--vscode] [query]
# Env:
# - FZF_FILE_OPEN_WITH: file opener: `vi` (default) or `vscode`.
# Notes:
# - `--vi` / `--vscode` override `FZF_FILE_OPEN_WITH`.
fzf-file() {
  typeset open_with=''
  typeset -a query_parts=()
  _fzf_parse_open_with_flags "$@" || return $?
  open_with="$REPLY"
  query_parts=("${reply[@]}")

  typeset file=''
  file=$(_fzf_file_select "${query_parts[*]}")
  [[ -z "$file" ]] && return 0

  _fzf_open_file "$open_with" "$file"
}

# fzf-git-status
# Interactive git status with diff preview.
# Usage: fzf-git-status [query]
# Notes:
# - Preview `git diff` for the selected path; supports preview scroll bindings.
fzf-git-status() {
  local query="$*"
  git status -s | fzf \
    --query="$query" \
    --preview 'bash -c '\''
      line=$1
      path=$(printf "%s" "$line" | cut -c4-)

      case "$path" in
        *" -> "*) path=$(printf "%s" "$path" | sed -E "s/^.* -> //") ;;
      esac

      first=$(printf "%s" "$path" | cut -c1)
      last=$(printf "%s" "$path" | tail -c 1)
      if [[ "$first" == "\"" && "$last" == "\"" ]]; then
        raw=$(printf "%s" "$path" | sed -E "s/^\"//; s/\"$//")
        path=$(printf "%b" "$raw")
      fi

      if git ls-files --others --exclude-standard -- "$path" | grep -q .; then
        printf "%s\n" "--- UNTRACKED ---"
        git diff --color=always --no-index /dev/null -- "$path" 2>/dev/null || true
        exit 0
      fi

      printed=0

      if ! git diff --cached --quiet -- "$path" >/dev/null 2>&1; then
        printf "%s\n" "--- STAGED ---"
        git diff --color=always --cached -- "$path"
        printed=1
      fi

      if ! git diff --quiet -- "$path" >/dev/null 2>&1; then
        if [ "$printed" -eq 1 ]; then
          printf "\n"
        fi
        printf "%s\n" "--- UNSTAGED ---"
        git diff --color=always -- "$path"
        printed=1
      fi

      if [ "$printed" -eq 0 ]; then
        printf "%s\n" "(no diff)"
      fi
    '\'' -- {}' \
    --bind=ctrl-j:preview-down \
    --bind=ctrl-k:preview-up
}

# _fzf_select_commit [query] [selected]
# Select a commit with preview.
# Usage: _fzf_select_commit [query] [selected]
# Output:
# - Returns two lines (query, selected commit line).
_fzf_select_commit() {
  local query="${1:-}"
  local selected="${2:-}"
  local result=''
  local debug=false debug_log=''
  if [[ -n "${FZF_GIT_COMMIT_DEBUG-}" && "${FZF_GIT_COMMIT_DEBUG-}" != "0" ]]; then
    debug=true
    debug_log="${FZF_GIT_COMMIT_DEBUG_LOG_FILE:-$HOME/.codex/output/fzf-git-commit.debug.log}"
    mkdir -p -- "${debug_log:h}"
    export FZF_GIT_COMMIT_DEBUG_LOG_FILE="$debug_log"
    print -r -- "----- $(date -Is) _fzf_select_commit query='${query}' selected='${selected}'" >>| "$debug_log"
  fi

  if [[ -n "$selected" ]]; then
    local restore_bind="focus:unbind(focus)+clear-query"
    [[ -n "$query" ]] && restore_bind="focus:unbind(focus)+change-query[[${query}]]"
    if $debug; then
      print -r -- "restore_bind=${restore_bind}" >>| "$debug_log"
      restore_bind="focus:unbind(focus)+execute-silent[sh -c 'printf \"%s\\n\" \"$1\" >> \"$FZF_GIT_COMMIT_DEBUG_LOG_FILE\"' -- 'focus q=[{q}] item=[{}]']+${restore_bind#focus:}"
    fi

    result=$(git log --color=always --no-decorate --date='format:%m-%d %H:%M' \
      --pretty=format:'%C(bold #82aaff)%h%C(reset) %C(#ecc48d)%cd%C(reset) %C(#7fdbca)%an%C(reset)%C(auto)%d%C(reset) %C(#d6deeb)%s%C(reset)' |
      fzf --ansi --reverse --track \
          --prompt="🌀 Commit > " \
          --preview-window="$right:50%:wrap" \
          --preview='git-scope commit {1} | sed "s/^📅.*/&\n/"' \
          --print-query \
          --bind="$restore_bind" \
          --query="$selected")
  else
    result=$(git log --color=always --no-decorate --date='format:%m-%d %H:%M' \
      --pretty=format:'%C(bold #82aaff)%h%C(reset) %C(#ecc48d)%cd%C(reset) %C(#7fdbca)%an%C(reset)%C(auto)%d%C(reset) %C(#d6deeb)%s%C(reset)' |
      fzf --ansi --reverse \
          --prompt="🌀 Commit > " \
          --preview-window="$right:50%:wrap" \
          --preview='git-scope commit {1} | sed "s/^📅.*/&\n/"' \
          --print-query \
          --query="$query")
  fi

  [[ -z "$result" ]] && return 1

  if $debug; then
    local out_query='' out_selected=''
    out_query=$(printf "%s\n" "$result" | sed -n '1p')
    out_selected=$(printf "%s\n" "$result" | sed -n '2p')
    print -r -- "fzf_out_query='${out_query}'" >>| "$debug_log"
    print -r -- "fzf_out_selected='${out_selected}'" >>| "$debug_log"
  fi

  # Return the full result with query line and selected commit line
  printf "%s\n" "$result"
  return 0
}

# fzf-git-checkout [query]
# Pick a commit and checkout.
# Usage: fzf-git-checkout [query]
# Notes:
# - Confirms checkout; offers auto-stash retry on failure.
fzf-git-checkout() {
  local query="$*"
  local ref='' result=''
  result=$(_fzf_select_commit "$query") || return 1

  ref=$(sed -n '2p' <<< "$result" | awk '{print $1}')

  _fzf_confirm "🚚 Checkout to commit %s? [y/N] " "$ref" || return 1

  if git checkout "$ref"; then
    return 0
  fi

  printf "⚠️  Checkout to '%s' failed. Likely due to local changes.\n" "$ref"
  _fzf_confirm "📦 Stash your current changes and retry checkout? [y/N] " || return 1

  local timestamp='' subject=''
  timestamp=$(date +%F_%H%M)
  subject=$(git log -1 --pretty=%s HEAD)
  local stash_msg="auto-stash ${timestamp} HEAD - ${subject}"

  git stash push -u -m "$stash_msg"
  printf "📦 Changes stashed: %s\n" "$stash_msg"

  git checkout "$ref" && printf "✅ Checked out to %s\n" "$ref"
}

# fzf-git-commit [--snapshot] [query]
# Browse commits and open changed files in an editor.
# Usage: fzf-git-commit [--snapshot] [query]
# Options:
# - --snapshot: Open the selected file snapshot from the chosen commit (exported to a temp file).
# Notes:
# - Optional query pre-fills the initial fzf search. If it also resolves to a commit ref, uses its short hash.
# - Default behavior opens the file in the current working tree (HEAD) at the same path; if missing, prompts to open snapshot.
# - Uses `FZF_FILE_OPEN_WITH` to choose editor: `vi` (default) or `vscode`.
# - In file picker: Enter opens multiple worktree files (up to `OPEN_CHANGED_FILES_MAX_FILES`); Ctrl-F opens the selected file only.
#   With `--snapshot`, Enter opens the selected snapshot; Ctrl-F opens the selected worktree file.
fzf-git-commit() {
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    printf "❌ Not inside a Git repository. Aborting.\n" >&2
    return 1
  fi

  _fzf_ensure_git_utils || return 1
  _fzf_ensure_git_scope || return 1

  zmodload zsh/zutil 2>/dev/null || {
    print -u2 -r -- "❌ zsh/zutil is required for zparseopts."
    return 1
  }

  typeset -A opts=()
  zparseopts -D -E -A opts -- \
    -snapshot || return 2

  typeset snapshot=false
  (( ${+opts[--snapshot]} )) && snapshot=true

  local input="$*"
  local full_hash='' commit='' file=''
  local tmp='' commit_query='' commit_query_restore='' selected_commit=''
  typeset open_with="${FZF_FILE_OPEN_WITH:-vi}"
  local repo_root=''
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || repo_root=''

  if [[ -n "$input" ]]; then
    full_hash=$(get_commit_hash "$input" 2>/dev/null)
    if [[ -n "$full_hash" ]]; then
      commit_query="${full_hash:0:7}"
    else
      commit_query="$input"
    fi
  fi

  while true; do
    local result=''
    result=$(_fzf_select_commit "$commit_query" "$selected_commit") || return 1

    commit_query_restore=$(sed -n '1p' <<< "$result")
    commit=$(sed -n '2p' <<< "$result" | awk '{print $1}')
    selected_commit="$commit"

    local stats_list='' file_list=() file_paths=() color='' stat_line=''
    stats_list=$(git show --numstat --format= "$commit")

    local kind='' path1='' path2='' filepath=''
    while IFS=$'\t' read -r kind path1 path2; do
      [[ -z "$kind" ]] && continue

      filepath="$path1"
      if [[ ( "$kind" == R* || "$kind" == C* ) && -n "$path2" ]]; then
        filepath="$path2"
      fi
      [[ -z "$filepath" ]] && continue

      color="$(_git_scope_kind_color "$kind")"
      stat_line=$(print -r -- "$stats_list" | awk -v f="$filepath" '$3 == f {
        a = ($1 == "-" ? 0 : $1)
        d = ($2 == "-" ? 0 : $2)
        printf "  [+" a " / -" d "]"
      }')
      file_list+=("$(printf "%b[%s] %s%s%b" "$color" "$kind" "$filepath" "$stat_line" "\033[0m")")
      file_paths+=("$filepath")
    done < <(git diff-tree --no-commit-id --name-status -r "$commit")

    local fzf_result='' mode_key='' selected_line='' selected_file=''
    fzf_result=$(printf "%s\n" "${file_list[@]}" |
      fzf --ansi \
          --expect=ctrl-f \
          --header='enter: open all (worktree) | ctrl-f: open selected' \
          --prompt="📄 Files in $commit > " \
          --preview-window='right:50%:wrap' \
          --preview='bash -c "
            filepath=\$(printf \"%s\\n\" {} | sed -E '\''s/^\[[^]]+\\] //; s/ *\\[\\+.*\\]$//'\'')
            git diff --color=always '"${commit}"'^! -- \$filepath |
            delta --width=100 --line-numbers |
            awk '\''NR==1 && NF==0 {next} {print}'\''"')

    mode_key=$(sed -n '1p' <<< "$fzf_result")
    selected_line=$(sed -n '2p' <<< "$fzf_result")
    selected_file=$(printf "%s\n" "$selected_line" | sed -E 's/^\[[^]]+\] //; s/ *\[\+.*\]$//')

    if [[ -z "$selected_file" ]]; then
      commit_query="$commit_query_restore"
      continue
    fi

    local open_snapshot="$snapshot"
    [[ "$mode_key" == "ctrl-f" ]] && open_snapshot=false

    if [[ "$mode_key" != "ctrl-f" ]] && ! $open_snapshot; then
      local -a worktree_files=()
      local rel='' abs=''
      for rel in "${file_paths[@]}"; do
        [[ -z "$rel" ]] && continue
        abs="${repo_root}/${rel}"
        [[ -f "$abs" ]] || continue
        worktree_files+=("$abs")
      done

      if (( ${#worktree_files[@]} == 0 )); then
        print -u2 -r -- "❌ No files exist in working tree for commit: $commit"
        commit_query="$commit_query_restore"
        continue
      fi

      local max_raw='' max_files=5
      max_raw="${OPEN_CHANGED_FILES_MAX_FILES:-5}"
      if [[ "$max_raw" == <-> ]]; then
        max_files="$max_raw"
      fi
      (( max_files > 0 )) || { commit_query="$commit_query_restore"; continue; }
      worktree_files=("${worktree_files[@]:0:$max_files}")

      if [[ "$open_with" == "vscode" ]]; then
        local ocf_cmd=''
        if command -v open-changed-files >/dev/null 2>&1; then
          ocf_cmd='open-changed-files'
        elif [[ -n "${ZDOTDIR-}" && -x "${ZDOTDIR}/tools/open-changed-files.zsh" ]]; then
          ocf_cmd="${ZDOTDIR}/tools/open-changed-files.zsh"
        elif [[ -x "$HOME/.config/zsh/tools/open-changed-files.zsh" ]]; then
          ocf_cmd="$HOME/.config/zsh/tools/open-changed-files.zsh"
        fi

        if [[ -n "$ocf_cmd" ]]; then
          "$ocf_cmd" --list --workspace-mode git --max-files "$max_files" -- "${worktree_files[@]}"
        else
          if ! command -v code >/dev/null 2>&1; then
            print -u2 -r -- "❌ 'code' not found"
            return 127
          fi
          code --new-window -- "$repo_root" "${worktree_files[@]}"
        fi
      else
        vi -- "${worktree_files[@]}"
      fi
      break
    fi

    local worktree_file="${repo_root}/${selected_file}"

    if ! $open_snapshot; then
      if [[ -e "$worktree_file" ]]; then
        if [[ "$open_with" == "vscode" ]]; then
          if ! _fzf_open_in_vscode_workspace "$repo_root" "$worktree_file"; then
            print -u2 -r -- "❌ Failed to open in VSCode; falling back to vi"
            vi -- "$worktree_file"
          fi
        else
          vi -- "$worktree_file"
        fi
        break
      fi

      print -u2 -r -- "❌ File no longer exists in working tree: $selected_file"
      _fzf_confirm "🧾 Open snapshot from %s instead? [y/N] " "$commit" || return 1
    fi

    tmp="$(mktemp 2>/dev/null || true)"
    [[ -n "$tmp" ]] || tmp="/tmp/git-${commit//\//_}-${selected_file##*/}.$$.tmp"

    {
      if ! git show "${commit}:${selected_file}" >| "$tmp" 2>/dev/null; then
        if ! git show "${commit}^:${selected_file}" >| "$tmp" 2>/dev/null; then
          print -u2 -r -- "❌ Failed to extract snapshot: ${commit}:${selected_file} (or ${commit}^:${selected_file})"
          return 1
        fi
      fi

      if [[ "$open_with" == "vscode" ]]; then
        if ! _fzf_open_in_vscode_workspace "$repo_root" "$tmp" --wait; then
          print -u2 -r -- "❌ Failed to open in VSCode; falling back to vi"
          vi -- "$tmp"
        fi
      else
        vi -- "$tmp"
      fi
    } always {
      command rm -f -- "$tmp" >/dev/null 2>&1 || true
    }
    break
  done
}

# fzf_block_preview <generator-fn> [default_query]
# Generic block generator + preview driver.
# Usage: fzf_block_preview <generator-fn> [default_query]
# Notes:
# - Requires FZF_DEF_DELIM and FZF_DEF_DELIM_END; copies result to clipboard.
fzf_block_preview() {
  typeset generator="$1"
  typeset default_query="${2:-}"
  tmpfile="$(mktemp)"

  delim="${FZF_DEF_DELIM}"
  enddelim="${FZF_DEF_DELIM_END}"

  if [[ -z "$delim" || -z "$enddelim" ]]; then
    printf "❌ Error: FZF_DEF_DELIM or FZF_DEF_DELIM_END is not set.\n"
    printf "💡 Please export FZF_DEF_DELIM and FZF_DEF_DELIM_END before running.\n"
    rm -f "$tmpfile"
    return 1
  fi

  $generator > "$tmpfile"

  previewscript="$(mktemp)"
  command cat > "$previewscript" <<'EOF'
#!/usr/bin/env -S awk -f
BEGIN {
  target      = ENVIRON["FZF_PREVIEW_TARGET"]
  start_delim = ENVIRON["FZF_DEF_DELIM"]
  end_delim   = ENVIRON["FZF_DEF_DELIM_END"]
  printing    = 0
}
{
  if ($0 == start_delim) {
    getline header
    if (header == target) {
      print header
      print ""
      printing = 1
      next
    }
  }
  if (printing && $0 == end_delim) exit
  if (printing) print
}
EOF

  chmod +x "$previewscript"

  selected=$(awk -v delim="$delim" '$0 == delim { getline; print }' "$tmpfile" |
    FZF_DEF_DELIM="$delim" \
    FZF_DEF_DELIM_END="$enddelim" \
    fzf --ansi --reverse --height=50% \
        --prompt="» Select > " \
        --query="$default_query" \
        --preview-window='right:70%:wrap' \
        --preview="FZF_PREVIEW_TARGET={} $previewscript $tmpfile")

  [[ -z "$selected" ]] && { rm -f "$tmpfile" "$previewscript"; return; }

  result=$(awk -v target="$selected" -v delim="$delim" -v enddelim="$enddelim" '
BEGIN { inside=0 }
{
  if ($0 == delim) {
    getline header
    if (header == target) {
      print header
      print ""
      inside = 1
      next
    }
  }
  if (inside && $0 == enddelim) exit
  if (inside) print
}
' "$tmpfile")

  printf "%s\n" "$result"
  printf "%s\n" "$result" | set_clipboard
  rm -f "$tmpfile" "$previewscript"
}

# ────────────────────────────────────────────────────────
# fzf-def docs: extract comment blocks above definitions
# - For first-party zsh files only (no plugins/).
# ────────────────────────────────────────────────────────
typeset -gA _FZF_DEF_FN_DOC_BY_NAME=()
typeset -gA _FZF_DEF_FN_DOC_BY_FILE=()
typeset -gA _FZF_DEF_ALIAS_DOC_BY_NAME=()
typeset -gi _FZF_DEF_DOC_CACHE_LAST_LOAD_EPOCH=0

# _fzf_def_doc_cache_enabled
# Return success if persistent doc cache is enabled.
# Usage: _fzf_def_doc_cache_enabled
# Env:
# - FZF_DEF_DOC_CACHE_ENABLED: when `true`, enable persistent doc cache.
_fzf_def_doc_cache_enabled() {
  emulate -L zsh
  setopt localoptions nounset

  zsh_env::is_true "${FZF_DEF_DOC_CACHE_ENABLED-}" "FZF_DEF_DOC_CACHE_ENABLED"
}

# _fzf_def_doc_cache_ttl_seconds
# Print cache TTL in seconds.
# Usage: _fzf_def_doc_cache_ttl_seconds
# Env:
# - FZF_DEF_DOC_CACHE_EXPIRE_MINUTES: cache TTL in minutes (default: 10).
_fzf_def_doc_cache_ttl_seconds() {
  emulate -L zsh
  setopt err_return

  local minutes="${FZF_DEF_DOC_CACHE_EXPIRE_MINUTES:-10}"
  [[ "$minutes" == <-> ]] || minutes=10
  (( minutes < 0 )) && minutes=0
  print -r -- $(( minutes * 60 ))
}

# _fzf_def_doc_cache_dir
# Print the cache directory used for persistent doc cache files.
# Usage: _fzf_def_doc_cache_dir
# Notes:
# - Uses `$ZSH_CACHE_DIR` when set; otherwise falls back to `${ZDOTDIR:-$HOME/.config/zsh}/cache`.
_fzf_def_doc_cache_dir() {
  emulate -L zsh
  setopt err_return

  if [[ -n "${ZSH_CACHE_DIR-}" ]]; then
    print -r -- "$ZSH_CACHE_DIR"
    return 0
  fi

  local root="${ZDOTDIR:-$HOME/.config/zsh}"
  print -r -- "${root:A}/cache"
}

# _fzf_def_doc_cache_timestamp_file
# Print the persistent cache timestamp file path.
# Usage: _fzf_def_doc_cache_timestamp_file
_fzf_def_doc_cache_timestamp_file() {
  emulate -L zsh
  setopt err_return

  local cache_dir=''
  cache_dir="$(_fzf_def_doc_cache_dir)"
  print -r -- "$cache_dir/fzf-def-doc.timestamp"
}

# _fzf_def_doc_cache_data_file
# Print the persistent cache data file path.
# Usage: _fzf_def_doc_cache_data_file
_fzf_def_doc_cache_data_file() {
  emulate -L zsh
  setopt err_return

  local cache_dir=''
  cache_dir="$(_fzf_def_doc_cache_dir)"
  print -r -- "$cache_dir/fzf-def-doc.cache.zsh"
}

# _fzf_def_list_first_party_files
# Print the list of first-party files to index for docblocks.
# Usage: _fzf_def_list_first_party_files
# Notes:
# - Excludes `plugins/`; includes `.zshrc`, `.zprofile`, and `scripts/`, `bootstrap/`, `tools/`.
_fzf_def_list_first_party_files() {
  emulate -L zsh
  setopt err_return

  local root="${ZDOTDIR:-$HOME/.config/zsh}"
  root="${root:A}"

  local -a files=()
  local file=''
  [[ -f "$root/.zshrc" ]] && files+=("$root/.zshrc")
  [[ -f "$root/.zprofile" ]] && files+=("$root/.zprofile")

  local dir=''
  for dir in "$root/scripts" "$root/bootstrap" "$root/tools"; do
    [[ -d "$dir" ]] || continue
    while IFS= read -r file; do
      files+=("$file")
    done < <(command find "$dir" -type f -name '*.zsh' -print 2>/dev/null | sort)
  done

  print -rl -- "${files[@]}"
}

# _fzf_def_index_file_docs <file>
# Index docblocks (comment blocks directly above defs) from a file into lookup tables.
# Usage: _fzf_def_index_file_docs <file>
_fzf_def_index_file_docs() {
  emulate -L zsh
  setopt err_return

  local file="${1-}"
  [[ -r "$file" ]] || return 0

  local -a comment_buf=()
  local line='' name='' doc='' key=''

  while IFS= read -r line; do
    if [[ "$line" =~ '^[[:space:]]*#' ]]; then
      comment_buf+=("$line")
      continue
    fi

    if [[ "$line" =~ '^[[:space:]]*$' ]]; then
      comment_buf=()
      continue
    fi

    if [[ "$line" =~ '^[[:space:]]*function[[:space:]]+([A-Za-z0-9_][A-Za-z0-9_:-]*)[[:space:]]*(\(\))?[[:space:]]*\{' ]]; then
      name="${match[1]}"
      if (( ${#comment_buf} )); then
        doc="${(F)comment_buf}"
        _FZF_DEF_FN_DOC_BY_NAME[$name]="$doc"
        key="${file}$'\t'${name}"
        _FZF_DEF_FN_DOC_BY_FILE[$key]="$doc"
      fi
      comment_buf=()
      continue
    fi

    if [[ "$line" =~ '^[[:space:]]*([A-Za-z0-9_][A-Za-z0-9_:-]*)[[:space:]]*\(\)[[:space:]]*\{' ]]; then
      name="${match[1]}"
      if (( ${#comment_buf} )); then
        doc="${(F)comment_buf}"
        _FZF_DEF_FN_DOC_BY_NAME[$name]="$doc"
        key="${file}$'\t'${name}"
        _FZF_DEF_FN_DOC_BY_FILE[$key]="$doc"
      fi
      comment_buf=()
      continue
    fi

    if [[ "$line" =~ '^[[:space:]]*alias[[:space:]]+(-g[[:space:]]+)?([A-Za-z0-9_][A-Za-z0-9_:-]*)[[:space:]]*=' ]]; then
      name="${match[2]}"
      if (( ${#comment_buf} )); then
        _FZF_DEF_ALIAS_DOC_BY_NAME[$name]="${(F)comment_buf}"
      fi
      comment_buf=()
      continue
    fi

    comment_buf=()
  done < "$file"
}

# _fzf_def_rebuild_doc_cache
# Load/rebuild docblock indexes for `fzf-tools def/function/alias` previews.
# Usage: _fzf_def_rebuild_doc_cache
# Env:
# - FZF_DEF_DOC_CACHE_ENABLED: when `true`, enable persistent cache.
# - FZF_DEF_DOC_CACHE_EXPIRE_MINUTES: cache TTL in minutes (default: 10).
# Notes:
# - When enabled, reads/writes cache files under `$ZSH_CACHE_DIR` (or fallback cache dir).
_fzf_def_rebuild_doc_cache() {
  emulate -L zsh
  setopt err_return

  local enabled=false
  if _fzf_def_doc_cache_enabled; then
    enabled=true
  fi

  local now_epoch=0 ttl_seconds=0
  local cache_dir='' cache_file='' cache_ts_file='' last_epoch_raw='' last_epoch=0

  if $enabled; then
    ttl_seconds="$(_fzf_def_doc_cache_ttl_seconds)"
    now_epoch="$(date +%s)"

    if (( _FZF_DEF_DOC_CACHE_LAST_LOAD_EPOCH > 0 && (now_epoch - _FZF_DEF_DOC_CACHE_LAST_LOAD_EPOCH) <= ttl_seconds )); then
      return 0
    fi

    cache_dir="$(_fzf_def_doc_cache_dir)"
    cache_file="$(_fzf_def_doc_cache_data_file)"
    cache_ts_file="$(_fzf_def_doc_cache_timestamp_file)"

    if [[ -r "$cache_file" && -r "$cache_ts_file" ]]; then
      last_epoch_raw="$(<"$cache_ts_file")"
      if [[ "$last_epoch_raw" == <-> ]]; then
        last_epoch="$last_epoch_raw"
      else
        last_epoch=0
      fi

      if (( last_epoch > 0 && (now_epoch - last_epoch) <= ttl_seconds )); then
        if source "$cache_file"; then
          _FZF_DEF_DOC_CACHE_LAST_LOAD_EPOCH="$now_epoch"
          return 0
        fi
      fi
    fi
  fi

  _FZF_DEF_FN_DOC_BY_NAME=()
  _FZF_DEF_FN_DOC_BY_FILE=()
  _FZF_DEF_ALIAS_DOC_BY_NAME=()

  local file=''
  while IFS= read -r file; do
    _fzf_def_index_file_docs "$file"
  done < <(_fzf_def_list_first_party_files)

  if $enabled; then
    [[ -n "$cache_dir" ]] || cache_dir="$(_fzf_def_doc_cache_dir)"
    [[ -n "$cache_file" ]] || cache_file="$(_fzf_def_doc_cache_data_file)"
    [[ -n "$cache_ts_file" ]] || cache_ts_file="$(_fzf_def_doc_cache_timestamp_file)"
    [[ -n "$now_epoch" && "$now_epoch" == <-> ]] || now_epoch="$(date +%s)"

    command mkdir -p "$cache_dir" 2>/dev/null || true
    typeset -p _FZF_DEF_FN_DOC_BY_NAME _FZF_DEF_FN_DOC_BY_FILE _FZF_DEF_ALIAS_DOC_BY_NAME 2>/dev/null \
      | sed -E 's/^typeset -A /typeset -gA /' >| "$cache_file" || true

    print -r -- "$now_epoch" >| "$cache_ts_file" || true
    _FZF_DEF_DOC_CACHE_LAST_LOAD_EPOCH="$now_epoch"
  fi
}

# fzf-def-doc-cache-rebuild
# Force rebuild of the persistent docblock cache used by `fzf-tools def/function/alias`.
# Usage: fzf-def-doc-cache-rebuild
# Output:
# - Writes `$ZSH_CACHE_DIR/fzf-def-doc.cache.zsh` and `$ZSH_CACHE_DIR/fzf-def-doc.timestamp`.
# Notes:
# - Rebuild is forced even when `FZF_DEF_DOC_CACHE_ENABLED=false` (setting is not persisted).
fzf-def-doc-cache-rebuild() {
  emulate -L zsh
  setopt err_return

  local cache_file='' cache_ts_file=''
  cache_file="$(_fzf_def_doc_cache_data_file)"
  cache_ts_file="$(_fzf_def_doc_cache_timestamp_file)"

  command rm -f -- "$cache_file" "$cache_ts_file" 2>/dev/null || true
  _FZF_DEF_DOC_CACHE_LAST_LOAD_EPOCH=0

  FZF_DEF_DOC_CACHE_ENABLED=true _fzf_def_rebuild_doc_cache

  if [[ -r "$cache_file" && -r "$cache_ts_file" ]]; then
    print -r -- "Rebuilt:"
    print -r -- "  - data:      $cache_file"
    print -r -- "  - timestamp: $cache_ts_file"
    return 0
  fi

  print -u2 -r -- "fzf-def-doc-cache-rebuild: cache files were not written"
  return 1
}

# _fzf_def_print_docblock_with_separators <docblock>
# Print a docblock wrapped by comment separators for preview readability.
# Usage: _fzf_def_print_docblock_with_separators <docblock>
# Env:
# - FZF_DEF_DOC_SEPARATOR_PAD: extra width added to the separator line (default: 2).
_fzf_def_print_docblock_with_separators() {
  emulate -L zsh
  setopt err_return

  local doc="${1-}"
  [[ -z "$doc" ]] && return 0

  local -a lines=()
  lines=("${(@f)doc}")

  local first_line="${lines[1]-}"
  local prefix=''
  if [[ -n "$first_line" && "$first_line" =~ '^([[:space:]]*)#' ]]; then
    prefix="${match[1]}"
  fi

  local -i max_len=0
  local line=''
  for line in "${lines[@]}"; do
    (( ${#line} > max_len )) && max_len=${#line}
  done

  local pad="${FZF_DEF_DOC_SEPARATOR_PAD:-2}"
  [[ "$pad" == <-> ]] || pad=2
  (( pad < 0 )) && pad=0

  local -i prefix_len=${#prefix}
  local -i dash_count=$(( max_len + pad - prefix_len - 2 ))
  (( dash_count < 0 )) && dash_count=0

  local dashes="${(l:$dash_count::-:)}"
  print -r -- "${prefix}# ${dashes}"
  print -r -- "$doc"
  print -r -- "${prefix}# ${dashes}"
}

# _fzf_def_print_function_doc <function_name>
# Print the cached docblock for a function (if any).
# Usage: _fzf_def_print_function_doc <function_name>
_fzf_def_print_function_doc() {
  emulate -L zsh
  setopt err_return

  local fn="${1-}"
  [[ -z "$fn" ]] && return 0

  local doc=''
  if (( ${+functions_source} )); then
    local source_file="${functions_source[$fn]-}"
    if [[ -n "$source_file" ]]; then
      doc="${_FZF_DEF_FN_DOC_BY_FILE[${source_file}$'\t'${fn}]-}"
    fi
  fi

  [[ -z "$doc" ]] && doc="${_FZF_DEF_FN_DOC_BY_NAME[$fn]-}"
  [[ -n "$doc" ]] && _fzf_def_print_docblock_with_separators "$doc"
}

# _fzf_def_print_alias_doc <alias_name>
# Print the cached docblock for an alias (if any).
# Usage: _fzf_def_print_alias_doc <alias_name>
_fzf_def_print_alias_doc() {
  emulate -L zsh
  setopt err_return

  local name="${1-}"
  [[ -z "$name" ]] && return 0

  local doc="${_FZF_DEF_ALIAS_DOC_BY_NAME[$name]-}"
  [[ -n "$doc" ]] && _fzf_def_print_docblock_with_separators "$doc"
}

# _gen_env_block
# Emit env var blocks for `fzf_block_preview`.
# Usage: _gen_env_block
_gen_env_block() {
  env | sort | while IFS='=' read -r name value; do
    printf "%s\n" "$FZF_DEF_DELIM"
    printf "🌱 %s\n" "$name"
    printenv "$name" | sed 's/^/  /'
    printf "%s\n\n" "$FZF_DEF_DELIM_END"
  done
}

# fzf-env [query]
# Browse environment variables with preview.
# Usage: fzf-env [query]
fzf-env() {
  fzf_block_preview _gen_env_block "$*"
}

# _gen_alias_block
# Emit alias definition blocks for `fzf_block_preview`.
# Usage: _gen_alias_block
_gen_alias_block() {
  alias | sort | while IFS='=' read -r name raw; do
    printf "%s\n" "$FZF_DEF_DELIM"
    printf "🔗 %s\n" "$name"
    _fzf_def_print_alias_doc "$name"
    alias "$name" | sed -E "s/^$name=//; s/^['\"](.*)['\"]$/\1/"
    printf "%s\n\n" "$FZF_DEF_DELIM_END"
  done
}

# fzf-alias [query]
# Browse aliases with preview.
# Usage: fzf-alias [query]
fzf-alias() {
  _fzf_def_rebuild_doc_cache
  fzf_block_preview _gen_alias_block "$*"
}

# _gen_function_block
# Emit function source blocks for `fzf_block_preview`.
# Usage: _gen_function_block
_gen_function_block() {
  for fn in ${(k)functions}; do
    printf "%s\n" "$FZF_DEF_DELIM"
    printf "🔧 %s\n" "$fn"
    _fzf_def_print_function_doc "$fn"
    functions "$fn" 2>/dev/null
    printf "%s\n\n" "$FZF_DEF_DELIM_END"
  done
}

# fzf-function [query]
# Browse functions with preview.
# Usage: fzf-function [query]
fzf-function() {
  _fzf_def_rebuild_doc_cache
  fzf_block_preview _gen_function_block "$*"
}

# _gen_all_def_block
# Emit combined env/alias/function blocks for `fzf_block_preview`.
# Usage: _gen_all_def_block
_gen_all_def_block() {
  _gen_env_block
  _gen_alias_block
  _gen_function_block
}

# fzf-def [query]
# Browse env, aliases, and functions with preview.
# Usage: fzf-def [query]
fzf-def() {
  _fzf_def_rebuild_doc_cache
  fzf_block_preview _gen_all_def_block "$*"
}

# fzf-directory
# Pick a directory, then browse files with preview.
# Usage: fzf-directory [--vi|--vscode] [query]
# Env:
# - FZF_FILE_MAX_DEPTH: max depth for file listing (default: 10).
# - FZF_FILE_OPEN_WITH: file opener for Step2: `vi` (default) or `vscode`.
# Notes:
# - `--vi` / `--vscode` override `FZF_FILE_OPEN_WITH`.
# - Step1 preserves directory query only.
# - Step2 keys: enter/ctrl-f opens file and exits, ctrl-d cd to directory and exits, esc returns to Step1.
# - Shows hidden dirs/files; follows symlinks; preview via eza/ls and bat/sed.
fzf-directory() {
  emulate -L zsh -o no_xtrace -o no_verbose

  if [[ ! -o interactive || ! -t 1 ]]; then
    return 0
  fi

  typeset open_with=''
  typeset -a query_parts=()
  _fzf_parse_open_with_flags "$@" || return $?
  open_with="$REPLY"
  query_parts=("${reply[@]}")

  typeset dir_query="${query_parts[*]}" dir_result='' dir=''
  typeset max_depth="${FZF_FILE_MAX_DEPTH:-10}"

  while true; do
    dir_result=$(
      fd --type d --hidden --follow --exclude .git 2>/dev/null |
        fzf --ansi \
            --prompt="📁 Directory > " \
            --preview 'command -v eza >/dev/null && eza -alhT --level=2 --color=always {} || ls -la {}' \
            --print-query \
            --query="$dir_query"
    ) || return 1

    dir_query=$(printf "%s\n" "$dir_result" | sed -n '1p')
    dir=$(printf "%s\n" "$dir_result" | sed -n '2p')
    [[ -z "$dir" ]] && return 1

    while true; do
      typeset file_result='' key='' file='' full_path=''
      file_result=$(
        (
          cd "$dir" 2>/dev/null || exit 1
          fd --type f --max-depth="$max_depth" --hidden --follow --exclude .git 2>/dev/null
        ) |
          FZF_DIRECTORY_ROOT="$dir" \
                fzf --ansi \
                    --prompt="📄 Files in ${dir:t} > " \
                --header='enter/ctrl-f: open (exit)    ctrl-d: cd (exit)    esc: back' \
                    --preview-window="${FZF_PREVIEW_WINDOW:-right:50%:wrap}" \
                    --preview='if command -v bat >/dev/null; then bat --color=always --style=numbers --line-range :200 -- "$FZF_DIRECTORY_ROOT"/{}; else sed -n "1,200p" "$FZF_DIRECTORY_ROOT"/{}; fi' \
                    --expect=enter,ctrl-f,ctrl-d
      ) || break

      key=$(printf "%s\n" "$file_result" | sed -n '1p')
      file=$(printf "%s\n" "$file_result" | sed -n '2p')

      case "$key" in
        ctrl-d)
          cd "$dir" || return 1
          return 0
          ;;
        enter | ctrl-f)
          [[ -z "$file" ]] && continue
          full_path="${dir%/}/${file}"
          _fzf_open_file "$open_with" "$full_path"
          return 0
          ;;
        *)
          ;;
      esac
    done
  done
}

# fzf-tools <command> [args...]
# Main dispatcher and help menu.
# Usage: fzf-tools <command> [args...]
# Notes:
# - Subcommands: file, directory, git-status, git-commit, git-checkout, git-branch, git-tag,
#   process, port, history, env, alias, function, def
fzf-tools() {
  typeset cmd="$1"

  if [[ -z "$cmd" || "$cmd" == "help" || "$cmd" == "--help" || "$cmd" == "-h" ]]; then
    printf "%s\n" "Usage: fzf-tools <command> [args]"
    printf "\n"
    printf "%s\n" "Commands:"
    printf "  %-16s  %s\n" \
      file         "Search and preview text files" \
      directory    "Search directories and cd into selection" \
      git-status   "Interactive git status viewer" \
      git-commit   "Browse commits and open changed files in editor" \
      git-checkout "Pick and checkout a previous commit" \
      git-branch   "Browse and checkout branches interactively" \
      git-tag      "Browse and checkout tags interactively" \
      process      "Browse and kill running processes (confirm before kill)" \
      port         "Browse listening ports and owners (confirm before kill)" \
      history      "Search and execute command history" \
      env          "Browse environment variables" \
      alias        "Browse shell aliases" \
      function     "Browse defined shell functions" \
      def          "Browse all definitions (env, alias, functions)"
    printf "\n"
    return 0
  fi

  shift

  case "$cmd" in
    file)             fzf-file "$@" ;;
    directory)        fzf-directory "$@" ;;
    git-status)       fzf-git-status "$@" ;;
    git-commit)       fzf-git-commit "$@" ;;
    git-checkout)     fzf-git-checkout "$@" ;;
    git-branch)       fzf-git-branch "$@" ;;
    git-tag)          fzf-git-tag "$@" ;;
    process)          fzf-process "$@" ;;
    port)             fzf-port "$@" ;;
    history)          fzf-history "$@" ;;
    env)              fzf-env "$@" ;;
    alias)            fzf-alias "$@" ;;
    function)         fzf-function "$@" ;;
    def)              fzf-def "$@" ;;
    *)
      printf "❗ Unknown command: %s\n" "$cmd"
      printf "Run 'fzf-tools help' for usage.\n"
      return 1 ;;
  esac
}
