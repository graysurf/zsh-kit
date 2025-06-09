#!/bin/bash

# ────────────────────────────────────────────────────────
# Aliases and Unalias
# ────────────────────────────────────────────────────────
unalias ft fzf-process fzf-env fp fgs fgc ff fv fsc 2>/dev/null

alias ft='fzf-tools'
alias fzf-process='ps aux | fzf'
alias fp='fzf-eza-directory'
alias fgs='fzf-git-status'
alias fgc='fzf-git-commit'
alias ff='fzf-file'
alias fv='fzf-vscode'
alias fsc='fzf-scope-commit'

# ────────────────────────────────────────────────────────
# fzf utilities
# ────────────────────────────────────────────────────────
# Fuzzy search command history and execute selected entry
fzf-history() {
  local history_output
  if [[ -n "$ZSH_NAME" ]]; then
    history_output=$(fc -l 1)
  else
    history_output=$(history)
  fi

  local selected
  selected=$(echo "$history_output" |
    fzf +s --tac |
    sed -E 's/ *[0-9]*\*? *//' |
    sed -E 's/\\/\\\\/g')

  [[ -n "$selected" ]] && eval "$selected"
}

# Fuzzy search files and change to selected file's directory
fzf-directory() {
  local file dir
  file=$(fd --type f --hidden --exclude .git --max-depth=$FZF_FILE_MAX_DEPTH |
    fzf --preview 'bat --color "always" {}' +m -q "$1") &&
    dir=$(dirname "$file") &&
    cd "$dir"
}

# Fuzzy select process and kill it with signal (default: SIGKILL)
fzf-kill() {
  local pid
  pid=$(ps -ef | sed 1d | fzf -m | awk '{print $2}')
  [[ -n "$pid" ]] && echo $pid | xargs kill -${1:-9}
}

# ────────────────────────────────────────────────────────
# fzf + eza integrations
# ────────────────────────────────────────────────────────
# Fuzzy change directory using eza to preview directory contents
fzf-cd() {
  local dir
  dir=$(eza --only-dirs --color=always |
    fzf --ansi \
        --preview "eza -alh --icons --group-directories-first --color=always {}") &&
    cd "$dir"
}

# Fuzzy search files and cd into the selected file's directory (with eza preview)
fzf-eza-directory() {
  local file
  file=$(fd --type f --hidden --exclude .git --max-depth=$FZF_FILE_MAX_DEPTH |
    fzf --preview 'eza -al --color=always $(dirname {})') &&
    cd "$(dirname \"$file\")"
}

# Fuzzy git status with diff preview and navigation bindings
fzf-git-status() {
  git status -s | fzf --no-sort \
    --preview 'git diff --color=always {2}' \
    --bind=ctrl-j:preview-down \
    --bind=ctrl-k:preview-up 
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
  local file
  file=$(__fzf_file_select)
  [[ -n "$file" ]] && vi "$file"
}

# Fuzzy search a file and open it with VSCode
fzf-vscode() {
  local file
  file=$(__fzf_file_select)
  [[ -n "$file" ]] && code "$file"
}

# FZF pick a commit and checkout to it
fzf-git-checkout() {
  local ref
  ref=$(git log --color=always --no-decorate --date='format:%m-%d %H:%M' \
    --pretty=format:'%C(auto)%h %C(blue)%cd %C(cyan)%an%C(reset) %C(yellow)%d%C(reset) %s' |
    fzf --ansi --no-sort --reverse \
        --delimiter=' ' \
        --with-nth=2.. \
        --preview-window="${FZF_PREVIEW_WINDOW:-right:40%:wrap}" \
        --preview='git-scope commit {1} | sed "s/^📅.*/&\\n/"' |
    awk '{print $1}')

  [[ -z "$ref" ]] && return

  if git checkout "$ref"; then
    return 0
  fi

  echo "⚠️  Checkout to '$ref' failed. Likely due to local changes."

  echo -n "📦 Stash your current changes and retry checkout? [y/N] "
  read -r confirm
  [[ "$confirm" != [yY] ]] && echo "🚫 Aborted." && return 1

  # combine stash message： current time + HEAD subject
  local timestamp subject
  timestamp=$(date +%F_%H%M)
  subject=$(git log -1 --pretty=%s HEAD)
  local stash_msg="auto-stash ${timestamp} HEAD - ${subject}"

  git stash push -u -m "$stash_msg"
  echo "📦 Changes stashed: $stash_msg"

  # checkout again
  git checkout "$ref" && echo "✅ Checked out to $ref"
}

# Fuzzy pick a git commit and preview/open its file contents
fzf-git-commit() {
  local input_ref="$1"
  local commit file tmp
  local commit_query=""
  local commit_query_restore=""

  if [[ -n "$input_ref" ]]; then
    local full_hash
    full_hash=$(get_commit_hash "$input_ref")
    [[ -z "$full_hash" ]] && echo "❌ Invalid ref: $input_ref" >&2 && return 1
    commit_query="${full_hash:0:7}"
  fi

  while true; do
    local result=''
    result=$(git log --oneline --color=always --decorate --date='format:%m-%d %H:%M'  \
      --pretty=format:'%C(auto)%h %C(blue)%cd %C(cyan)%an%C(reset)%C(yellow)%d%C(reset) %s' |
      fzf --ansi --no-sort --reverse \
          --preview-window='right:50%:wrap' \
          --query="$commit_query" \
          --print-query \
          --preview 'git-scope commit $(echo {} | awk "{print \$1}") | sed "s/^📅.*/&\\n/"')
    [[ -z "$result" ]] && return

    commit_query_restore=$(sed -n '1p' <<< "$result")
    commit=$(sed -n '2p' <<< "$result" | awk '{print $1}')

    local COLOR_RESET='\033[0m'
    local ADDED='\033[1;32m'
    local MODIFIED='\033[1;33m'
    local DELETED='\033[1;31m'
    local OTHER='\033[1;34m'

    local stats_list=""
    stats_list=$(git show --numstat --format= "$commit")

    local -a file_list=()
    while IFS=$'\t' read -r kind filepath; do
      local color="$OTHER"
      case "$kind" in
        A) color="$ADDED" ;;
        M) color="$MODIFIED" ;;
        D) color="$DELETED" ;;
        U) color="$OTHER" ;;
        *) color="$COLOR_RESET" ;;
      esac

      local stat_line=''
      stat_line=$(echo "$stats_list" | awk -v f="$filepath" '$3 == f {
        a = ($1 == "-" ? 0 : $1)
        d = ($2 == "-" ? 0 : $2)
        printf "  [+" a " / -" d "]"
      }')

      file_list+=("$(printf "%b[%s] %s%s%b" "$color" "$kind" "$filepath" "$stat_line" "$COLOR_RESET")")
    done < <(git diff-tree --no-commit-id --name-status -r "$commit")

    file=$(printf "%s\n" "${file_list[@]}" |
      fzf --ansi \
          --prompt="📄 Files in $commit > " \
          --preview-window='right:50%:wrap' \
          --preview='bash -c "
            filepath=\$(echo {} | sed -E '\''s/^\[[A-Z]\] //; s/ *\[\+.*\]$//'\'')
            git diff --color=always '"${commit}"'^! -- \$filepath | delta --width=100 --line-numbers"' |
      sed -E 's/^\[[A-Z]\] //; s/ *\[\+.*\]$//'
    )

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

# Fuzzy search git commits with preview using git-scope
fzf-scope-commit() {
  git log --oneline --color=always --decorate --date='format:%m-%d %H:%M'  \
      --pretty=format:'%C(auto)%h %C(blue)%cd %C(cyan)%an%C(reset)%C(yellow)%d%C(reset) %s' |
    fzf --ansi --no-sort --reverse \
        --preview-window='right:50%:wrap' \
        --preview 'git-scope commit $(echo {} | awk "{print \$1}") | sed "s/^📅.*/&\\n/"'\
        --bind "enter:execute(clear && git-scope commit {1})+abort"
}

# Show delimited preview blocks in FZF and copy selected block to clipboard
fzf_block_preview() {
  local generator="$1"
  local tmpfile delim enddelim
  tmpfile="$(mktemp)"

  # 檢查 delimiter 變數是否設置，未設置就報錯退出
  delim="${FZF_DEF_DELIM}"
  enddelim="${FZF_DEF_DELIM_END}"

  if [[ -z "$delim" || -z "$enddelim" ]]; then
    echo "❌ Error: FZF_DEF_DELIM or FZF_DEF_DELIM_END is not set."
    echo "💡 Please export FZF_DEF_DELIM and FZF_DEF_DELIM_END before running."
    rm -f "$tmpfile"
    return 1
  fi

  $generator > "$tmpfile"

  local previewscript
  previewscript="$(mktemp)"
  cat > "$previewscript" <<'EOF'
#!/usr/bin/env awk -f

# This AWK script is used by fzf preview to extract a specific block
# from a temp file containing multiple sections delimited by markers.
#
# Required ENV variables:
# - FZF_PREVIEW_TARGET: The block header to match
# - FZF_DEF_DELIM:       The line that marks the start of each block
# - FZF_DEF_DELIM_END:   The line that marks the end of each block

BEGIN {
  target      = ENVIRON["FZF_PREVIEW_TARGET"]
  start_delim = ENVIRON["FZF_DEF_DELIM"]
  end_delim   = ENVIRON["FZF_DEF_DELIM_END"]
  printing    = 0
}

{
  # Detect start of block
  if ($0 == start_delim) {
    getline header
    if (header == target) {
      print header
      print ""           # Add spacing before content
      printing = 1
      next
    }
  }

  # Stop when reaching end of block
  if (printing && $0 == end_delim)
    exit

  # Print block content
  if (printing)
    print
}
EOF

  chmod +x "$previewscript"

  local selected
  selected=$(awk -v delim="$delim" '$0 == delim { getline; print }' "$tmpfile" |
    FZF_DEF_DELIM="$delim" \
    FZF_DEF_DELIM_END="$enddelim" \
    fzf --ansi \
        --prompt="» Select > " \
        --preview-window='right:70%:wrap' \
        --preview="FZF_PREVIEW_TARGET={} $previewscript $tmpfile")

  [[ -z "$selected" ]] && { rm -f "$tmpfile" "$previewscript"; return }

  local result
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

  echo "$result"
  echo "$result" | pbcopy  
  rm -f "$tmpfile" "$previewscript"
}

# Generate environment variable blocks for preview
_gen_env_block() {
  env | sort | while IFS='=' read -r name value; do
    echo "$FZF_DEF_DELIM"
    echo "🌱 $name"
    printenv "$name"
    echo "$FZF_DEF_DELIM_END"
    echo ""
  done
}

# Fuzzy search environment variables with preview
fzf-env() {
  fzf_block_preview _gen_env_block
}

# Generate alias definition blocks for preview
_gen_alias_block() {
  alias | sort | while IFS='=' read -r name raw; do
    echo "$FZF_DEF_DELIM"
    echo "🔗 $name"
    alias "$name" | sed -E "s/^$name=//; s/^['\"](.*)['\"]$/\1/"
    echo "$FZF_DEF_DELIM_END"
    echo ""
  done
}

# Fuzzy search shell aliases with preview
fzf-alias() {
  fzf_block_preview _gen_alias_block
}

# Generate function blocks for preview from defined shell functions
_gen_function_block() {
  for fn in ${(k)functions}; do
    echo "$FZF_DEF_DELIM"
    echo "🔧 $fn"
    functions "$fn" 2>/dev/null
    echo "$FZF_DEF_DELIM_END"
    echo ""
  done
}

# Fuzzy search shell functions with preview
fzf-functions() {
  fzf_block_preview _gen_function_block
}

# Generate combined block of env, alias, and function definitions
_gen_all_defs_block() {
  _gen_env_block
  _gen_alias_block
  _gen_function_block
}

# Fuzzy search all definitions (env, alias, function) with preview
fzf-defs() {
  fzf_block_preview _gen_all_defs_block
}

# ────────────────────────────────────────────────────
# Main fzf-tools command
# ────────────────────────────────────────────────────

# Dispatcher and help menu for various fzf-based utilities
fzf-tools() {
  local cmd="$1"

  if [[ -z "$cmd" || "$cmd" == "help" || "$cmd" == "--help" || "$cmd" == "-h" ]]; then
    echo "Usage: fzf-tools <command> [args...]"
    echo ""
    echo "Commands:"
    printf "  %-18s %s\n" \
      cd "Change directory using fzf and eza" \
      directory "Preview file and cd into its folder" \
      file "Search and preview text files" \
      vscode "Search and preview text files in VSCode" \
      git-status "Interactive git status viewer" \
      git-commit "Browse commits and open changed files in VSCode" \
      git-scope-commit "Browse commit log and open scope viewer" \
      kill "Kill a selected process" \
      history "Search and execute command history" \
      env "Browse environment variables" \
      alias "Browse shell aliases" \
      functions "Browse defined shell functions" \
      defs "Browse all definitions (env, alias, functions)"
    echo ""
    return 0
  fi

  shift

  case "$cmd" in
    cd)               fzf-cd "$@" ;;
    directory)        fzf-eza-directory "$@" ;;
    file)             fzf-file "$@" ;;
    vscode)           fzf-vscode "$@" ;;
    git-status)       fzf-git-status "$@" ;;
    git-commit)       fzf-git-commit "$@" ;;
    git-scope-commit) fzf-scope-commit "$@" ;;
    kill)             fzf-kill "$@" ;;
    history)          fzf-history "$@" ;;
    env)              fzf-env "$@" ;;
    alias)            fzf-alias "$@" ;;
    functions)        fzf-functions "$@" ;;
    defs)             fzf-defs "$@" ;;
    *)
      echo "❗ Unknown command: $cmd"
      echo "Run 'fzf-tools help' for usage."
      return 1 ;;
  esac
}
