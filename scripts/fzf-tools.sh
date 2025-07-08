# ────────────────────────────────────────────────────────
# Aliases and Unalias
# ────────────────────────────────────────────────────────
if command -v safe_unalias >/dev/null; then
  safe_unalias ft fzf-process fzf-kill-process fzf-env fp fgs fgc ff fv
fi

alias ft='fzf-tools'
alias fgs='fzf-git-status'
alias fgc='fzf-git-commit'
alias ff='fzf-file'
alias fv='fzf-vscode'

# ────────────────────────────────────────────────────────
# fzf utilities
# ────────────────────────────────────────────────────────

# Fuzzy select and kill a process (simple fallback)
fzf-process() {
  local kill_mode=false
  [[ "$1" == "--kill" || "$1" == "-k" ]] && kill_mode=true

  local line
  line=$(ps -eo user,pid,ppid,pcpu,pmem,stat,lstart,time,args | sed 1d | \
    fzf -m \
      --preview-window='right:30%:wrap' \
      --preview='echo {} | awk '\''{
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
  pids=$(echo "$line" | awk '{print $2}')

  if $kill_mode && [[ -n "$pids" ]]; then
    printf "☠️  Killing PID(s): %s\n" "$pids"
    echo "$pids" | xargs kill -9
  fi
}

# Fuzzy search command history and execute selected entry
fzf-history() {
  typeset history_output
  if [[ -n "$ZSH_NAME" ]]; then
    history_output=$(fc -l 1)
  else
    history_output=$(history)
  fi

  typeset selected
  selected=$(echo "$history_output" |
    fzf +s --tac |
    sed -E 's/ *[0-9]*\*? *//' |
    sed -E 's/\\/\\\\/g')

  [[ -n "$selected" ]] && eval "$selected"
}

# ────────────────────────────────────────────────────────
# fzf file preview helper
# ────────────────────────────────────────────────────────
__fzf_file_select() {
  fd --type f --max-depth=${FZF_FILE_MAX_DEPTH:-5} --hidden 2>/dev/null |
    fzf --ansi \
        --preview 'bat --color=always --style=numbers --line-range :100 {}'
}

# Fuzzy search a file and open it with vi
fzf-file() {
  typeset file
  file=$(__fzf_file_select)
  [[ -n "$file" ]] && vi "$file"
}

# Fuzzy search a file and open it with VSCode
fzf-vscode() {
  typeset file
  file=$(__fzf_file_select)
  [[ -n "$file" ]] && code "$file"
}

# Fuzzy git status with diff preview and navigation bindings
fzf-git-status() {
  git status -s | fzf \
    --preview 'git diff --color=always {2}' \
    --bind=ctrl-j:preview-down \
    --bind=ctrl-k:preview-up 
}

# Common helper to select a commit with fzf and preview
__fzf_select_commit() {
  local query="${1:-}"
  local result
  result=$(git log --color=always --no-decorate --date='format:%m-%d %H:%M' \
    --pretty=format:'%C(auto)%h %C(blue)%cd %C(cyan)%an%C(reset) %C(yellow)%d%C(reset) %s' |
    fzf --ansi --reverse \
        --preview-window="${FZF_PREVIEW_WINDOW:-right:40%:wrap}" \
        --preview='git-scope commit {1} | sed "s/^📅.*/&\n/"' \
        --print-query \
        --query="$query")

  [[ -z "$result" ]] && return 1

  # Return the full result with query line and selected commit line
  printf "%s\n" "$result"
  return 0
}

# FZF pick a commit and checkout to it
fzf-git-checkout() {
  local ref
  local confirm
  local result
  result=$(__fzf_select_commit) || return 1

  ref=$(sed -n '2p' <<< "$result" | awk '{print $1}')

  printf "🚚 Checkout to commit %s? [y/N] " "$ref"
  read -r confirm
  [[ "$confirm" != [yY] ]] && printf "🚫 Aborted.\n" && return 1

  if git checkout "$ref"; then
    return 0
  fi

  printf "⚠️  Checkout to '%s' failed. Likely due to local changes.\n" "$ref"
  printf "📦 Stash your current changes and retry checkout? [y/N] "
  read -r confirm
  [[ "$confirm" != [yY] ]] && printf "🚫 Aborted.\n" && return 1

  local timestamp subject
  timestamp=$(date +%F_%H%M)
  subject=$(git log -1 --pretty=%s HEAD)
  local stash_msg="auto-stash ${timestamp} HEAD - ${subject}"

  git stash push -u -m "$stash_msg"
  printf "📦 Changes stashed: %s\n" "$stash_msg"

  git checkout "$ref" && printf "✅ Checked out to %s\n" "$ref"
}

fzf-git-commit() {
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    printf "❌ Not inside a Git repository. Aborting.\n" >&2
    return 1
  fi

  local input_ref="$1"
  local full_hash commit file tmp commit_query commit_query_restore
  commit_query=""

  if [[ -n "$input_ref" ]]; then
    full_hash=$(get_commit_hash "$input_ref")
    [[ -z "$full_hash" ]] && printf "❌ Invalid ref: %s\n" "$input_ref" >&2 && return 1
    commit_query="${full_hash:0:7}"
  fi

  while true; do
    local result
    result=$(__fzf_select_commit "$commit_query") || return 1

    commit_query_restore=$(sed -n '1p' <<< "$result")
    commit=$(sed -n '2p' <<< "$result" | awk '{print $1}')

    local stats_list file_list color stat_line
    stats_list=$(git show --numstat --format= "$commit")
    file_list=()

    while IFS=$'\t' read -r kind filepath; do
      [[ -z "$filepath" ]] && continue
      color="$(_git_scope_kind_color "$kind")"
      stat_line=$(echo "$stats_list" | awk -v f="$filepath" '$3 == f {
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
            filepath=\$(echo {} | sed -E '\''s/^\[[A-Z]\] //; s/ *\[\+.*\]$//'\'')
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
  cat > "$previewscript" <<'EOF'
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

# Generate environment variable blocks for preview
_gen_env_block() {
  env | sort | while IFS='=' read -r name value; do
    printf "%s\n" "$FZF_DEF_DELIM"
    printf "🌱 %s\n" "$name"
    printenv "$name" | sed 's/^/  /'
    printf "%s\n\n" "$FZF_DEF_DELIM_END"
  done
}

# Fuzzy search environment variables with preview
fzf-env() {
  fzf_block_preview _gen_env_block ${1:-}
}

# Generate alias definition blocks for preview
_gen_alias_block() {
  alias | sort | while IFS='=' read -r name raw; do
    printf "%s\n" "$FZF_DEF_DELIM"
    printf "🔗 %s\n" "$name"
    alias "$name" | sed -E "s/^$name=//; s/^['\"](.*)['\"]$/\1/"
    printf "%s\n\n" "$FZF_DEF_DELIM_END"
  done
}

# Fuzzy search shell aliases with preview
fzf-alias() {
  fzf_block_preview _gen_alias_block ${1:-}
}

# Generate function blocks for preview from defined shell functions
_gen_function_block() {
  for fn in ${(k)functions}; do
    printf "%s\n" "$FZF_DEF_DELIM"
    printf "🔧 %s\n" "$fn"
    functions "$fn" 2>/dev/null
    printf "%s\n\n" "$FZF_DEF_DELIM_END"
  done
}

# Fuzzy search shell functions with preview
fzf-functions() {
  fzf_block_preview _gen_function_block ${1:-}
}

# Generate combined block of env, alias, and function definitions
_gen_all_defs_block() {
  _gen_env_block
  _gen_alias_block
  _gen_function_block
}

# Fuzzy search all definitions (env, alias, function) with preview
fzf-defs() {
  fzf_block_preview _gen_all_defs_block ${1:-}
}

# ────────────────────────────────────────────────────────
# Select a file using `fd` and `fzf`, then open it with $EDITOR
# - Shows hidden files and follows symlinks
# - Uses `bat` for preview (requires bat installed)
# - Falls back cleanly if no file is selected
# ────────────────────────────────────────────────────────
fzf-fdf() {
  typeset file
  file=$(fd --type f --hidden --follow --exclude .git \
    | fzf --ansi --preview 'bat --style=numbers --color=always --line-range :100 {}')

  [[ -n "$file" ]] && "${EDITOR:-nvim}" "$file"
}

# ────────────────────────────────────────────────────────
# Select a directory using `fd` and `fzf`, then cd into it
# - Shows hidden directories and follows symlinks
# - Uses `eza` to preview contents (fallback to `ls` if not available)
# - Falls back cleanly if no directory is selected
# ────────────────────────────────────────────────────────
fzf-fdd() {
  typeset dir
  dir=$(fd --type d --hidden --follow --exclude .git \
    | fzf --ansi --preview 'command -v eza >/dev/null && eza -alhT --level=2 --color=always {} || ls -la {}')

  [[ -n "$dir" ]] && cd "$dir"
}

# ────────────────────────────────────────────────────
# Main fzf-tools command dispatcher and help menu
# ────────────────────────────────────────────────────
fzf-tools() {
  typeset cmd="$1"

  if [[ -z "$cmd" || "$cmd" == "help" || "$cmd" == "--help" || "$cmd" == "-h" ]]; then
    printf "%s\n" "Usage: fzf-tools <command> [args...]"
    printf "\n"
    printf "%s\n" "Commands:"
    printf "  %-18s %s\n" \
      file "Search and preview text files" \
      vscode "Search and preview text files in VSCode" \
      fdf "Search files and open with \$EDITOR" \
      fdd "Search directories and cd into selection" \
      git-status "Interactive git status viewer" \
      git-commit "Browse commits and open changed files in VSCode" \
      git-checkout "Pick and checkout a previous commit" \
      process "Browse and kill running processes (view-only by default)" \
      history "Search and execute command history" \
      env "Browse environment variables" \
      alias "Browse shell aliases" \
      functions "Browse defined shell functions" \
      defs "Browse all definitions (env, alias, functions)"
    printf "\n"
    return 0
  fi

  shift

  case "$cmd" in
    file)             fzf-file "$@" ;;
    vscode)           fzf-vscode "$@" ;;
    fdf)              fzf-fdf "$@" ;;
    fdd)              fzf-fdd "$@" ;;
    git-status)       fzf-git-status "$@" ;;
    git-commit)       fzf-git-commit "$@" ;;
    git-checkout)     fzf-git-checkout "$@" ;;
    process)          fzf-process "$@" ;;
    history)          fzf-history "$@" ;;
    env)              fzf-env "$@" ;;
    alias)            fzf-alias "$@" ;;
    functions)        fzf-functions "$@" ;;
    defs)             fzf-defs "$@" ;;
    *)
      printf "❗ Unknown command: %s\n" "$cmd"
      printf "Run 'fzf-tools help' for usage.\n"
      return 1 ;;
  esac
}
