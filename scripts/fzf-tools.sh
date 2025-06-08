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
# Environment config
# ────────────────────────────────────────────────────────
# Set max depth for fd-based searches
export FZF_FILE_MAX_DEPTH=5
export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS \
  --preview-window=right:60%:wrap \
  --bind=ctrl-j:preview-down \
  --bind=ctrl-k:preview-up \
  --bind=ctrl-l:preview-page-down \
  --bind=ctrl-h:preview-page-up"

# FZF key bindings (e.g., Ctrl-R, Ctrl-T, Alt-C)
source "/opt/homebrew/opt/fzf/shell/key-bindings.zsh"

export FZF_CTRL_T_COMMAND='fd --type f -t d --hidden --follow --exclude .git -E .cache'
export FZF_CTRL_T_OPTS="--preview 'bat --color \"always\" {}'"
export FZF_ALT_C_COMMAND="fd --type d --hidden --follow"

# ────────────────────────────────────────────────────────
# fzf utilities
# ────────────────────────────────────────────────────────
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

fzf-directory() {
  local file dir
  file=$(fd --type f --hidden --exclude .git --max-depth=$FZF_FILE_MAX_DEPTH |
    fzf --preview 'bat --color "always" {}' +m -q "$1") &&
    dir=$(dirname "$file") &&
    cd "$dir"
}

fzf-kill() {
  local pid
  pid=$(ps -ef | sed 1d | fzf -m | awk '{print $2}')
  [[ -n "$pid" ]] && echo $pid | xargs kill -${1:-9}
}

# ────────────────────────────────────────────────────────
# fzf + eza integrations
# ────────────────────────────────────────────────────────
fzf-cd() {
  local dir
  dir=$(eza --only-dirs --color=always |
    fzf --ansi \
        --preview "eza -alh --icons --group-directories-first --color=always {}") &&
    cd "$dir"
}

fzf-eza-directory() {
  local file
  file=$(fd --type f --hidden --exclude .git --max-depth=$FZF_FILE_MAX_DEPTH |
    fzf --preview 'eza -al --color=always $(dirname {})') &&
    cd "$(dirname \"$file\")"
}

fzf-git-status() {
  git status -s | fzf --no-sort --reverse \
    --preview 'git diff --color=always {2}' \
    --bind=ctrl-j:preview-down \
    --bind=ctrl-k:preview-up \
    --preview-window=right:60%:wrap
}

# ────────────────────────────────────────────────────────
# fzf file preview helper
# ────────────────────────────────────────────────────────
__fzf_file_select() {
  fd --type f --max-depth=${FZF_FILE_MAX_DEPTH:-5} --hidden 2>/dev/null |
    fzf --ansi \
        --preview 'bat --color=always --style=numbers --line-range :100 {}' \
        --preview-window=right:60%:wrap
}

fzf-file() {
  local file
  file=$(__fzf_file_select)
  [[ -n "$file" ]] && vi "$file"
}

fzf-vscode() {
  local file
  file=$(__fzf_file_select)
  [[ -n "$file" ]] && code "$file"
}

fzf-git-commit() {
  local commit file

  echo -n "Enter commit hash (or leave empty to pick): "
  read -r input

  if [[ -n "$input" ]]; then
    commit="$input"
  else
    commit=$(git log --oneline --color=always |
      fzf --ansi --no-sort --reverse --height=40% |
      awk '{print $1}')
  fi

  [[ -z "$commit" ]] && return

  file=$(git diff-tree --no-commit-id --name-only -r "$commit" |
    fzf --preview "git show ${commit}:{} | bat --color=always --style=numbers --line-range :100 --file-name={}" \
        --preview-window=right:60%:wrap)

  [[ -n "$file" ]] && {
    tmp="/tmp/git-${commit//\//_}-${file##*/}"
    git show "${commit}:${file}" > "$tmp"
    code "$tmp"
  }
}

fzf-scope-commit() {
  git log --oneline --no-color |
    fzf --ansi --no-sort \
        --preview 'git scope commit $(echo {} | awk "{print \$1}") | sed "s/^📅.*/&\\n/"'\
        --preview-window=right:60%:wrap \
        --bind "enter:execute(clear && git-scope commit {1})+abort"
}

# ────────────────────────────────────────────────────
# Main fzf-tools command
# ────────────────────────────────────────────────────

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
      history "Search and execute command history"
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
    *)
      echo "❗ Unknown command: $cmd"
      echo "Run 'fzf-tools help' for usage."
      return 1 ;;
  esac
}

export FZF_DEF_DELIM='"[FZF-DEF]'
export FZF_DEF_DELIM_END='[FZF-DEF-END]'

fzf_block_preview() {
  local generator="$1"
  local tmpfile delim enddelim
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
        --preview="FZF_PREVIEW_TARGET={} $previewscript $tmpfile" \
        --preview-window=right:60%)

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


_gen_env_block() {
  env | sort | while IFS='=' read -r name value; do
    echo "$FZF_DEF_DELIM"
    echo "🌱 $name"
    printenv "$name"
    echo "$FZF_DEF_DELIM_END"
    echo ""
  done
}

fzf-env() {
  fzf_block_preview _gen_env_block
}

_gen_alias_block() {
  alias | sort | while IFS='=' read -r name raw; do
    echo "$FZF_DEF_DELIM"
    echo "🔗 $name"
    alias "$name" | sed -E "s/^$name=//; s/^['\"](.*)['\"]$/\1/"
    echo "$FZF_DEF_DELIM_END"
    echo ""
  done
}

fzf-alias() {
  fzf_block_preview _gen_alias_block
}

_gen_function_block() {
  for fn in ${(k)functions}; do
    echo "$FZF_DEF_DELIM"
    echo "🔧 $fn"
    functions "$fn" 2>/dev/null
    echo "$FZF_DEF_DELIM_END"
    echo ""
  done
}

fzf-functions() {
  fzf_block_preview _gen_function_block
}

_gen_all_defs_block() {
  _gen_env_block
  _gen_alias_block
  _gen_function_block
}

fzf-defs() {
  fzf_block_preview _gen_all_defs_block
}
