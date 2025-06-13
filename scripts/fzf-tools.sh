# ────────────────────────────────────────────────────────
# Aliases and Unalias
# ────────────────────────────────────────────────────────
if command -v safe_unalias >/dev/null; then
  safe_unalias ft fzf-process fzf-env fp fgs fgc ff fv
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
  local kill_mode="$1"
  local line

  line=$(ps -ef | sed 1d | fzf -m --preview 'echo {}') || return

  local pids=$(echo "$line" | awk '{print $2}')

  if [[ "$kill_mode" == "--kill" && -n "$pids" ]]; then
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

# FZF pick a commit and checkout to it
fzf-git-checkout() {
  typeset ref
  ref=$(git log --color=always --no-decorate --date='format:%m-%d %H:%M' \
    --pretty=format:'%C(auto)%h %C(blue)%cd %C(cyan)%an%C(reset) %C(yellow)%d%C(reset) %s' |
    fzf --ansi --reverse \
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
  typeset timestamp subject
  timestamp=$(date +%F_%H%M)
  subject=$(git log -1 --pretty=%s HEAD)
  typeset stash_msg="auto-stash ${timestamp} HEAD - ${subject}"

  git stash push -u -m "$stash_msg"
  echo "📦 Changes stashed: $stash_msg"

  # checkout again
  git checkout "$ref" && echo "✅ Checked out to $ref"
}

# Fuzzy pick a git commit and preview/open its file contents
fzf-git-commit() {
  typeset input_ref="$1"
  typeset commit file tmp
  typeset commit_query=""
  typeset commit_query_restore=""

  if [[ -n "$input_ref" ]]; then
    typeset full_hash
    full_hash=$(get_commit_hash "$input_ref")
    [[ -z "$full_hash" ]] && echo "❌ Invalid ref: $input_ref" >&2 && return 1
    commit_query="${full_hash:0:7}"
  fi

  while true; do
    typeset result=''
    result=$(git log --oneline --color=always --decorate --date='format:%m-%d %H:%M'  \
      --pretty=format:'%C(auto)%h %C(blue)%cd %C(cyan)%an%C(reset)%C(yellow)%d%C(reset) %s' |
      fzf --ansi --reverse \
          --preview-window='right:50%:wrap' \
          --query="$commit_query" \
          --print-query \
          --preview 'git-scope commit $(echo {} | awk "{print \$1}") | tail -n +2 | sed "s/^📅.*/&\\n/"')
    [[ -z "$result" ]] && return

    commit_query_restore=$(sed -n '1p' <<< "$result")
    commit=$(sed -n '2p' <<< "$result" | awk '{print $1}')

    typeset COLOR_RESET='\033[0m'
    typeset ADDED='\033[1;32m'
    typeset MODIFIED='\033[1;33m'
    typeset DELETED='\033[1;31m'
    typeset OTHER='\033[1;34m'

    typeset stats_list=""
    stats_list=$(git show --numstat --format= "$commit")

    typeset -a file_list=()
    while IFS=$'\t' read -r kind filepath; do
      typeset color="$OTHER"
      case "$kind" in
        A) color="$ADDED" ;;
        M) color="$MODIFIED" ;;
        D) color="$DELETED" ;;
        U) color="$OTHER" ;;
        *) color="$COLOR_RESET" ;;
      esac

      typeset stat_line=''
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

# Show delimited preview blocks in FZF and copy selected block to clipboard
fzf_block_preview() {
  typeset generator="$1"
  typeset tmpfile delim enddelim
  tmpfile="$(mktemp)"

  delim="${FZF_DEF_DELIM}"
  enddelim="${FZF_DEF_DELIM_END}"

  if [[ -z "$delim" || -z "$enddelim" ]]; then
    echo "❌ Error: FZF_DEF_DELIM or FZF_DEF_DELIM_END is not set."
    echo "💡 Please export FZF_DEF_DELIM and FZF_DEF_DELIM_END before running."
    rm -f "$tmpfile"
    return 1
  fi

  $generator > "$tmpfile"

  typeset previewscript
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

  typeset selected
  selected=$(awk -v delim="$delim" '$0 == delim { getline; print }' "$tmpfile" |
    FZF_DEF_DELIM="$delim" \
    FZF_DEF_DELIM_END="$enddelim" \
    fzf --ansi --reverse --height=50% \
        --prompt="» Select > " \
        --preview-window='right:70%:wrap' \
        --preview="FZF_PREVIEW_TARGET={} $previewscript $tmpfile")

  [[ -z "$selected" ]] && { rm -f "$tmpfile" "$previewscript"; return }

  typeset result
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
  echo "$result" | set_clipboard  
  rm -f "$tmpfile" "$previewscript"
}

# Generate environment variable blocks for preview
_gen_env_block() {
  env | sort | while IFS='=' read -r name value; do
    echo "$FZF_DEF_DELIM"
    echo "🌱 $name"
    printenv "$name" | sed 's/^/  /'
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
# Main fzf-tools command
# ────────────────────────────────────────────────────

# Dispatcher and help menu for various fzf-based utilities
fzf-tools() {
  typeset cmd="$1"

  if [[ -z "$cmd" || "$cmd" == "help" || "$cmd" == "--help" || "$cmd" == "-h" ]]; then
    echo "Usage: fzf-tools <command> [args...]"
    echo ""
    echo "Commands:"
    printf "  %-18s %s\n" \
      file "Search and preview text files" \
      vscode "Search and preview text files in VSCode" \
      fdf "Search files and open with \$EDITOR" \
      fdd "Search directories and cd into selection" \
      git-status "Interactive git status viewer" \
      git-commit "Browse commits and open changed files in VSCode" \
      git-checkout "Pick and checkout a previous commit" \
      process "Browse and kill running processes" \
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
      echo "❗ Unknown command: $cmd"
      echo "Run 'fzf-tools help' for usage."
      return 1 ;;
  esac
}
