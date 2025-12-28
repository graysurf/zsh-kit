# ────────────────────────────────────────────────────────
# Aliases and Unalias
# ────────────────────────────────────────────────────────
if command -v safe_unalias >/dev/null; then
  safe_unalias ft fzf-process fzf-env fzf-port fp fgs fgc ff fv
fi

alias ft='fzf-tools'
alias fgs='fzf-git-status'
alias fgc='fzf-git-commit'
alias ff='fzf-file'
alias fv='fzf-vscode'
alias fp='fzf-port'

# ────────────────────────────────────────────────────────
# fzf utilities
# ────────────────────────────────────────────────────────

_fzf_confirm() {
  local prompt="${1-}"
  [[ -z "$prompt" ]] && return 1
  shift

  printf "$prompt" "$@"

  local confirm
  read -r confirm
  [[ "$confirm" != [yY] ]] && printf "🚫 Aborted.\n" && return 1
  return 0
}

_fzf_script_root() {
  local script_root=""
  if [[ -n "${ZSH_SCRIPT_DIR-}" ]]; then
    script_root="$ZSH_SCRIPT_DIR"
  elif [[ -n "${ZDOTDIR-}" ]]; then
    script_root="$ZDOTDIR/scripts"
  else
    script_root="$HOME/.config/zsh/scripts"
  fi

  print -r -- "$script_root"
}

_fzf_ensure_git_utils() {
  if typeset -f get_commit_hash >/dev/null 2>&1; then
    return 0
  fi

  local script_root
  script_root="$(_fzf_script_root)"

  [[ -f "$script_root/git/tools/git-utils.zsh" ]] && source "$script_root/git/tools/git-utils.zsh"
  if ! typeset -f get_commit_hash >/dev/null 2>&1; then
    printf "❌ get_commit_hash is unavailable. Ensure git utils are loaded.\n" >&2
    return 1
  fi

  return 0
}

_fzf_ensure_git_scope() {
  if typeset -f _git_scope_kind_color >/dev/null 2>&1; then
    return 0
  fi

  local script_root
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
# - _fzf_parse_kill_flags: parse -k/--kill and -9/--force into globals
# - _fzf_kill_flow: common confirmation + signal dispatch
# ────────────────────────────────────────────────────────
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
}

# Handle interactive/non-interactive kill confirmation and dispatch
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
  local force
  read -r force
  if [[ "$force" == [yY] ]]; then
    printf "☠️  Killing PID(s) with SIGKILL: %s\n" "$pids"
    print -r -- "$pids" | xargs kill -9
  else
    printf "☠️  Killing PID(s) with SIGTERM: %s\n" "$pids"
    print -r -- "$pids" | xargs kill
  fi
}

# ────────────────────────────────────────────────────────
# fzf-git-branch: Browse and checkout branches
# Usage: fzf-git-branch
# - Shows recent branches; preview displays recent commit graph.
# - Confirms before `git checkout`.
# ────────────────────────────────────────────────────────
fzf-git-branch() {
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    printf "❌ Not inside a Git repository. Aborting.\n" >&2
    return 1
  fi

  # List local branches, strip '* ' from current, but show it
  local selected
  selected=$(git branch --color=always --sort=-committerdate | \
    sed 's/^..//' | \
    fzf --ansi --reverse \
      --prompt="🌿 Branch > " \
      --preview-window="right:60%:wrap" \
      --preview='
        branch=$(printf "%s\n" {} | sed "s/^[* ]*//")
        [[ -z "$branch" ]] && exit 0
        git log -n 100 --graph --color=always --decorate --abbrev-commit --date=iso-local \
         --pretty=format:"%C(auto)%h %ad %C(cyan)%an%C(reset)%d %s" "$branch"' \
  )
  [[ -z "$selected" ]] && return 1

  # Remove any leading '*' and spaces
  local branch
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

# ────────────────────────────────────────────────────────
# fzf-git-tag: Browse and checkout tags
# Usage: fzf-git-tag
# - Lists tags (newest first); preview shows commit log for the tag.
# - Confirms before checking out the tag's commit.
# ────────────────────────────────────────────────────────
fzf-git-tag() {
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    printf "❌ Not inside a Git repository. Aborting.\n" >&2
    return 1
  fi

  # List tags, sorted by most recent
  local selected
  selected=$(git tag --sort=-creatordate | \
    fzf --ansi --reverse \
      --prompt="🏷️  Tag > " \
      --preview-window="right:60%:wrap" \
      --preview='
        tag=$(printf "%s\n" {} | sed "s/^[* ]*//")
        [[ -z "$tag" ]] && exit 0
        hash=$(git rev-parse --verify --quiet "${tag}^{commit}")
        [[ -z "$hash" ]] && printf "❌ Could not resolve tag to commit.\n" && exit 0
        git log -n 100 --graph --color=always --decorate --abbrev-commit --date=iso-local \
          --pretty=format:"%C(auto)%h %ad %C(cyan)%an%C(reset)%d %s" "$hash"
      ' \
  )
  [[ -z "$selected" ]] && return 1

  # Remove any leading '*' and spaces (shouldn't be present for tags, but for symmetry)
  local tag
  tag=$(print -r -- "$selected" | sed 's/^[* ]*//')

  # Pre-resolve tag to commit hash for preview and checkout
  _fzf_ensure_git_utils || return 1

  local hash
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

# ────────────────────────────────────────────────────────
# fzf-process: Browse processes and optionally kill
# Usage: fzf-process [-k|--kill] [-9|--force]
# - Default: select rows → confirm kill → optional confirm SIGKILL (-9).
# - Flags: -k immediate kill (SIGTERM); add -9/--force for SIGKILL.
# - Multi-select supported. Preview shows CPU/MEM/PPID/start/time/cmd.
# ────────────────────────────────────────────────────────
fzf-process() {
  # Flags: -k/--kill (no prompt), -9/--force (SIGKILL)
  _fzf_parse_kill_flags "$@"
  local kill_now="$_fzf_kill_now" force_kill="$_fzf_force_kill"

  local line
  line=$(ps -eo user,pid,ppid,pcpu,pmem,stat,lstart,time,args | sed 1d | \
    fzf -m \
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

  local pids
  pids=$(print -r -- "$line" | awk '{print $2}')
  _fzf_kill_flow "$pids" "$kill_now" "$force_kill"
}

# ────────────────────────────────────────────────────────
# fzf-port: Browse listening TCP ports and owning PIDs
# Usage: fzf-port [-k|--kill] [-9|--force]
# - Default: select rows → confirm kill owning PIDs → optional confirm SIGKILL.
# - Flags: -k immediate kill (SIGTERM); add -9/--force for SIGKILL.
# - Uses: lsof -nP -iTCP -sTCP:LISTEN; falls back to netstat (view-only).
# - Preview: protocol, addr:port, cmd, user, pid; plus lsof -p details.
# ────────────────────────────────────────────────────────
fzf-port() {
  # Flags: -k/--kill (no prompt), -9/--force (SIGKILL)
  _fzf_parse_kill_flags "$@"
  local kill_now="$_fzf_kill_now" force_kill="$_fzf_force_kill"

  # Prefer lsof for cross-platform listing (macOS/Linux). Show TCP LISTEN and UDP sockets.
  local line
  if command -v lsof >/dev/null 2>&1; then
    # Limit to TCP listeners explicitly (-iTCP) so state filter is reliable across platforms
    line=$(lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | sed 1d | \
      fzf -m \
        --prompt="🔌 Port > " \
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
        --preview-window='right:50%:wrap' \
        --preview='printf "%s\n\n(netstat view; no lsof PID info)\n" {}') || return
  fi

  # Extract PIDs (lsof output second column). Deduplicate.
  local pids
  pids=$(print -r -- "$line" | awk '{print $2}' | sort -u)
  _fzf_kill_flow "$pids" "$kill_now" "$force_kill"
}

# ────────────────────────────────────────────────────────
# fzf-history-select: Build and select shell history entries
# Usage: fzf-history-select
# - Presents history with timestamps; preview shows formatted time + command.
# - Returns two lines (key, selected) for consumption by fzf-history.
# ────────────────────────────────────────────────────────
fzf-history-select() {
  local default_query="${BUFFER:-}"

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

      gsub(/\\/, "\\\\", cmd)
      printf "%s | %4d | %s\n", ts, NR, cmd
    }
  ' | tac | fzf --ansi --reverse --height=50% \
         --query="$default_query" \
         --preview-window='right:40%:wrap' \
         --preview='ts=$(cut -d"|" -f1 <<< {} | sed "s/[[:space:]]*$//"); \
fts=$(date -r "$ts" "+%Y-%m-%d %H:%M:%S"); \
cmd=$(cut -d"|" -f3- <<< {} | sed -E "s/^[[:space:]]*(🖥️|🧪|🐧|🐳|🛠️)?[[:space:]]*//"); \
printf "%s\n\n%s" "$fts" "$cmd"' \
         --expect=enter
}

# ────────────────────────────────────────────────────────
# fzf-history: Search and execute a history command
# Usage: fzf-history
# - Uses fzf-history-select; executes selected command.
# ────────────────────────────────────────────────────────
fzf-history() {
  local selected output cmd

  output="$(fzf-history-select)"
  selected="$(printf "%s\n" "$output" | sed -n '2p')"

  cmd="$(printf "%s\n" "$selected" | cut -d'|' -f3- | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  cmd="$(printf "%s\n" "$cmd" | sed -E 's/^[[:space:]]*(🖥️|🧪|🐧|🐳|🛠️)?[[:space:]]*//')"

  [[ -n "$cmd" ]] && eval "$cmd"
}

# ────────────────────────────────────────────────────────
# _fzf_file_select: File selector with bat preview
# Usage: _fzf_file_select
# - Helper used by fzf-file and fzf-vscode.
# ────────────────────────────────────────────────────────
_fzf_file_select() {
  fd --type f --max-depth=${FZF_FILE_MAX_DEPTH:-5} --hidden 2>/dev/null |
    fzf --ansi \
        --preview 'bat --color=always --style=numbers --line-range :100 {}'
}

# ────────────────────────────────────────────────────────
# fzf-file: Pick a file and open with $EDITOR
# Usage: fzf-file
# ────────────────────────────────────────────────────────
fzf-file() {
  typeset file
  file=$(_fzf_file_select)
  [[ -n "$file" ]] && $EDITOR "$file"
}

# ────────────────────────────────────────────────────────
# fzf-vscode: Pick a file and open in VSCode
# Usage: fzf-vscode
# ────────────────────────────────────────────────────────
fzf-vscode() {
  typeset file
  file=$(_fzf_file_select)
  [[ -n "$file" ]] && code "$file"
}

# ────────────────────────────────────────────────────────
# fzf-git-status: Interactive git status with diff preview
# Usage: fzf-git-status
# - Preview `git diff` for the selected path; supports preview scroll bindings.
# ────────────────────────────────────────────────────────
fzf-git-status() {
  git status -s | fzf \
    --preview 'git diff --color=always {2}' \
    --bind=ctrl-j:preview-down \
    --bind=ctrl-k:preview-up
}

# ────────────────────────────────────────────────────────
# _fzf_select_commit: Select a commit with preview
# Usage: _fzf_select_commit [query]
# - Returns two lines (query, selected commit line).
# ────────────────────────────────────────────────────────
_fzf_select_commit() {
  local query="${1:-}"
  local result
  result=$(git log --color=always --no-decorate --date='format:%m-%d %H:%M' \
    --pretty=format:'%C(auto)%h %C(blue)%cd %C(cyan)%an%C(reset) %C(yellow)%d%C(reset) %s' |
    fzf --ansi --reverse \
        --prompt="🌀 Commit > " \
        --preview-window="${FZF_PREVIEW_WINDOW:-right:40%:wrap}" \
        --preview='git-scope commit {1} | sed "s/^📅.*/&\n/"' \
        --print-query \
        --query="$query")

  [[ -z "$result" ]] && return 1

  # Return the full result with query line and selected commit line
  printf "%s\n" "$result"
  return 0
}

# ────────────────────────────────────────────────────────
# fzf-git-checkout: Pick a commit and checkout
# Usage: fzf-git-checkout
# - Confirms checkout; offers auto-stash retry on failure.
# ────────────────────────────────────────────────────────
fzf-git-checkout() {
  local ref result
  result=$(_fzf_select_commit) || return 1

  ref=$(sed -n '2p' <<< "$result" | awk '{print $1}')

  _fzf_confirm "🚚 Checkout to commit %s? [y/N] " "$ref" || return 1

  if git checkout "$ref"; then
    return 0
  fi

  printf "⚠️  Checkout to '%s' failed. Likely due to local changes.\n" "$ref"
  _fzf_confirm "📦 Stash your current changes and retry checkout? [y/N] " || return 1

  local timestamp subject
  timestamp=$(date +%F_%H%M)
  subject=$(git log -1 --pretty=%s HEAD)
  local stash_msg="auto-stash ${timestamp} HEAD - ${subject}"

  git stash push -u -m "$stash_msg"
  printf "📦 Changes stashed: %s\n" "$stash_msg"

  git checkout "$ref" && printf "✅ Checked out to %s\n" "$ref"
}

# ────────────────────────────────────────────────────────
# fzf-git-commit: Browse commits, open changed files in VSCode
# Usage: fzf-git-commit [ref]
# - Optional ref narrows initial query; per-commit file picker with previews.
# ────────────────────────────────────────────────────────
fzf-git-commit() {
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    printf "❌ Not inside a Git repository. Aborting.\n" >&2
    return 1
  fi

  _fzf_ensure_git_utils || return 1
  _fzf_ensure_git_scope || return 1

  local input_ref="$1"
  local full_hash="" commit="" file=""
  local tmp="" commit_query="" commit_query_restore=""

  if [[ -n "$input_ref" ]]; then
    full_hash=$(get_commit_hash "$input_ref")
    [[ -z "$full_hash" ]] && printf "❌ Invalid ref: %s\n" "$input_ref" >&2 && return 1
    commit_query="${full_hash:0:7}"
  fi

  while true; do
    local result=""
    result=$(_fzf_select_commit "$commit_query") || return 1

    commit_query_restore=$(sed -n '1p' <<< "$result")
    commit=$(sed -n '2p' <<< "$result" | awk '{print $1}')

    local stats_list="" file_list=() color="" stat_line=""
    stats_list=$(git show --numstat --format= "$commit")

    while IFS=$'\t' read -r kind filepath; do
      [[ -z "$filepath" ]] && continue
      color="$(_git_scope_kind_color "$kind")"
      stat_line=$(print -r -- "$stats_list" | awk -v f="$filepath" '$3 == f {
        a = ($1 == "-" ? 0 : $1)
        d = ($2 == "-" ? 0 : $2)
        printf "  [+" a " / -" d "]"
      }')
      file_list+=("$(printf "%b[%s] %s%s%b" "$color" "$kind" "$filepath" "$stat_line" "\033[0m")")
    done < <(git diff-tree --no-commit-id --name-status -r "$commit")

    file=$(printf "%s\n" "${file_list[@]}" |
      fzf --ansi --prompt="📄 Files in $commit > " \
          --preview-window='right:50%:wrap' \
          --preview='bash -c "
            filepath=\$(printf \"%s\\n\" {} | sed -E '\''s/^\[[A-Z]\] //; s/ *\[\+.*\]$//'\'')
            git diff --color=always '"${commit}"'^! -- \$filepath |
            delta --width=100 --line-numbers |
            awk '\''NR==1 && NF==0 {next} {print}'\''"' |
      sed -E 's/^\[[A-Z]\] //; s/ *\[\+.*\]$//')

    if [[ -z "$file" ]]; then
      commit_query="$commit_query_restore"
      continue
    fi

    tmp="/tmp/git-${commit//\//_}-${file##*/}"
    git show "${commit}:${file}" > "$tmp"
    code "$tmp"
    break
  done
}

# ────────────────────────────────────────────────────────
# fzf_block_preview: Generic block generator + preview driver
# Usage: fzf_block_preview <generator-fn> [default_query]
# - Requires FZF_DEF_DELIM and FZF_DEF_DELIM_END; copies result to clipboard.
# ────────────────────────────────────────────────────────
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
#!/usr/bin/env awk -f
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
# _gen_env_block: Emit env var blocks (for fzf_block_preview)
# ────────────────────────────────────────────────────────
_gen_env_block() {
  env | sort | while IFS='=' read -r name value; do
    printf "%s\n" "$FZF_DEF_DELIM"
    printf "🌱 %s\n" "$name"
    printenv "$name" | sed 's/^/  /'
    printf "%s\n\n" "$FZF_DEF_DELIM_END"
  done
}

# ────────────────────────────────────────────────────────
# fzf-env: Browse environment variables with preview
# Usage: fzf-env [query]
# ────────────────────────────────────────────────────────
fzf-env() {
  fzf_block_preview _gen_env_block ${1:-}
}

# ────────────────────────────────────────────────────────
# _gen_alias_block: Emit alias definition blocks
# ────────────────────────────────────────────────────────
_gen_alias_block() {
  alias | sort | while IFS='=' read -r name raw; do
    printf "%s\n" "$FZF_DEF_DELIM"
    printf "🔗 %s\n" "$name"
    alias "$name" | sed -E "s/^$name=//; s/^['\"](.*)['\"]$/\1/"
    printf "%s\n\n" "$FZF_DEF_DELIM_END"
  done
}

# ────────────────────────────────────────────────────────
# fzf-alias: Browse aliases with preview
# Usage: fzf-alias [query]
# ────────────────────────────────────────────────────────
fzf-alias() {
  fzf_block_preview _gen_alias_block ${1:-}
}

# ────────────────────────────────────────────────────────
# _gen_function_block: Emit function source blocks
# ────────────────────────────────────────────────────────
_gen_function_block() {
  for fn in ${(k)functions}; do
    printf "%s\n" "$FZF_DEF_DELIM"
    printf "🔧 %s\n" "$fn"
    functions "$fn" 2>/dev/null
    printf "%s\n\n" "$FZF_DEF_DELIM_END"
  done
}

# ────────────────────────────────────────────────────────
# fzf-function: Browse functions with preview
# Usage: fzf-function [query]
# ────────────────────────────────────────────────────────
fzf-function() {
  fzf_block_preview _gen_function_block ${1:-}
}

# ────────────────────────────────────────────────────────
# _gen_all_def_block: Emit combined env/alias/function blocks
# ────────────────────────────────────────────────────────
_gen_all_def_block() {
  _gen_env_block
  _gen_alias_block
  _gen_function_block
}

# ────────────────────────────────────────────────────────
# fzf-def: Browse env, aliases, and functions with preview
# Usage: fzf-def [query]
# ────────────────────────────────────────────────────────
fzf-def() {
  fzf_block_preview _gen_all_def_block ${1:-}
}

# ────────────────────────────────────────────────────────
# fzf-directory: Select a directory (fd + fzf) and cd
# Usage: fzf-directory
# - Shows hidden dirs; follows symlinks; preview via eza/ls.
# ────────────────────────────────────────────────────────
fzf-directory() {
  typeset dir
  dir=$(fd --type d --hidden --follow --exclude .git \
    | fzf --ansi --preview 'command -v eza >/dev/null && eza -alhT --level=2 --color=always {} || ls -la {}')

  [[ -n "$dir" ]] && cd "$dir"
}

# ────────────────────────────────────────────────────────
# fzf-tools: Main dispatcher and help menu
# Usage: fzf-tools <command> [args]
# - See help output for subcommands.
# ────────────────────────────────────────────────────────
fzf-tools() {
  typeset cmd="$1"

  if [[ -z "$cmd" || "$cmd" == "help" || "$cmd" == "--help" || "$cmd" == "-h" ]]; then
    printf "%s\n" "Usage: fzf-tools <command> [args]"
    printf "\n"
    printf "%s\n" "Commands:"
    printf "  %-16s  %s\n" \
      file         "Search and preview text files" \
      vscode       "Search and preview text files in VSCode" \
      directory    "Search directories and cd into selection" \
      git-status   "Interactive git status viewer" \
      git-commit   "Browse commits and open changed files in VSCode" \
      git-checkout "Pick and checkout a previous commit" \
      git-branch   "Browse and checkout branches interactively" \
      git-tag      "Browse and checkout tags interactively" \
      process      "Browse and kill running processes (confirm before kill)" \
      port         "Browse listening ports and owners (confirm before kill)" \
      history      "Search and execute command history" \
      env          "Browse environment variables" \
      alias        "Browse shell aliases" \
      functions    "Browse defined shell functions" \
      def          "Browse all definitions (env, alias, functions)"
    printf "\n"
    return 0
  fi

  shift

  case "$cmd" in
    file)             fzf-file "$@" ;;
    vscode)           fzf-vscode "$@" ;;
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
    def)             fzf-def "$@" ;;
    *)
      printf "❗ Unknown command: %s\n" "$cmd"
      printf "Run 'fzf-tools help' for usage.\n"
      return 1 ;;
  esac
}
