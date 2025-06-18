# ────────────────────────────────────────────────────────
# Aliases and Unalias
# ────────────────────────────────────────────────────────
if command -v safe_unalias >/dev/null; then
  safe_unalias gsc gst
fi

alias gsc='git-scope commit'
alias gst='git-scope tracked'

# Return ANSI color code based on file change kind
_git_scope_kind_color() {
  case "$1" in
    A) printf '\033[38;5;66m'  ;;  # Added    → #3d6f6f (Delta plus-style)
    M) printf '\033[38;5;110m' ;;  # Modified → #add6ff (Delta file-style)
    D) printf '\033[38;5;95m'  ;;  # Deleted  → #5a3e39 (Delta minus-style)
    U) printf '\033[38;5;110m' ;;  # Unknown  → fallback Owl Blue (#82aaff)
    -) printf '\033[0m'        ;;  # Reset
    *) printf '\033[38;5;110m' ;;  # Fallback
  esac
}

# Render directory tree from a list of file paths
_git_scope_render_tree() {
  typeset -a file_list=("${(@f)}$1")

  if [[ "${#file_list[@]}" -eq 0 ]]; then
    printf "⚠️ No files to render as tree\n"
    return 1
  fi

  printf "\n📂 Directory tree:\n"

  printf "%s\n" "${file_list[@]}" | awk -F/ '{
    path=""
    for(i=1;i<NF;i++) {
      path = (path ? path "/" $i : $i)
      print path
    }
    print $0
  }' | sort -u | tree --fromfile -C
}


# Render file list with A/M/D tags and color, then show tree
_git_scope_render_with_type() {
  typeset input="$1"

  if [[ -z "$input" ]]; then
    printf "⚠️  No matching files\n"
    return 1
  fi

  typeset COLOR_RESET='\033[0m'
  typeset -a files=()

  printf "\n📄 Changed files:\n"

  while IFS=$'\t' read -r kind file; do
    [[ -z "$file" ]] && continue
    files+=("$file")
    typeset color="$(_git_scope_kind_color "$kind")"
    printf "  %b➔ [%s] %s%b\n" "$color" "$kind" "$file" "$COLOR_RESET"
  done <<< "$input"

  _git_scope_render_tree "${(F)files}"

  if [[ "$_git_scope_should_print" == true ]]; then
    printf "\n📦 Printing file contents:\n"
    for file in "${files[@]}"; do
      print_file_content "$file"
      printf "\n"
    done
  fi
}


# Common file status collector
_git_scope_collect() {
  typeset mode="$1"
  shift

  typeset -a args=()
  _git_scope_should_print=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p|--print)
        _git_scope_should_print=true ;;
      *)
        args+=("$1") ;;
    esac
    shift
  done

  case "$mode" in
    staged)
      git diff --cached --name-status --diff-filter=ACMRTUXB ;;
    modified)
      git diff --name-status --diff-filter=ACMRTUXB ;;
    all)
      printf "%s\n%s" \
        "$(git diff --cached --name-status --diff-filter=ACMRTUXB)" \
        "$(git diff --name-status --diff-filter=ACMRTUXB)" | grep -v '^$' | sort -u ;;
    tracked)
      typeset -a prefixes=("${args[@]}")
      typeset files all_filtered
      files=$(git ls-files)
      if [[ ${#prefixes[@]} -gt 0 ]]; then
      for prefix in "${prefixes[@]}"; do
        clean_prefix="${prefix%/}"

        if [[ -d "$clean_prefix" ]]; then
          all_filtered+=$'\n'$(printf '%s\n' "$files" | grep "^${clean_prefix}/")
        elif [[ -f "$clean_prefix" ]]; then
          all_filtered+=$'\n'$(printf '%s\n' "$files" | grep -x "$clean_prefix")
        else
          # fallback: partial match if neither file nor dir exists locally
          all_filtered+=$'\n'$(printf '%s\n' "$files" | grep "^${clean_prefix}")
        fi
      done
        files="$(printf '%s\n' "$all_filtered" | grep -v '^$' | sort -u)"
      fi
      printf '%s\n' "$files" | while IFS= read -r f; do
        [[ -n "$f" ]] && printf "-\t%s\n" "$f"
      done ;;
    untracked)
      git ls-files --others --exclude-standard | while IFS= read -r f; do
        [[ -n "$f" ]] && printf "U\t%s\n" "$f"
      done ;;
    commit)
      typeset commit="${args[1]}"
      git show --pretty=format: --name-status "$commit" ;;
    *)
      printf "⚠️ Unknown collect mode: %s\n" "$mode" >&2
      return 1 ;;
  esac
}

# Print full content of a given file, from working tree or HEAD fallback
print_file_content() {
  typeset file="$1"

  if [[ -z "$file" ]]; then
    printf "❗ Missing file path\n"
    return 1
  fi

  if [[ -f "$file" ]]; then
    if file --mime "$file" | grep -q 'charset=binary'; then
      printf "📄 %s (binary file in working tree)\n" "$file"
      printf "🔹 [Binary file content omitted]\n"
    else
      printf "📄 %s (working tree)\n" "$file"
      printf '```\n'
      cat -- "$file"
      printf '\n```\n'
    fi
  elif git cat-file -e "HEAD:$file" 2>/dev/null; then
    typeset tmp
    tmp="$(mktemp)"
    git show "HEAD:$file" > "$tmp"

    if file --mime "$tmp" | grep -q 'charset=binary'; then
      printf "📄 %s (binary file in HEAD)\n" "$file"
      printf "🔹 [Binary file content omitted]\n"
    else
      printf "📄 %s (from HEAD)\n" "$file"
      printf '```\n'
      cat -- "$tmp"
      printf '\n```\n'
    fi

    rm -f "$tmp"
  else
    printf "❗ File not found: %s\n" "$file"
    return 1
  fi
}

# Command handlers
_git_scope_tracked()   { _git_scope_render_with_type "$(_git_scope_collect tracked "$@")"; }
_git_scope_staged()    { _git_scope_render_with_type "$(_git_scope_collect staged "$@")"; }
_git_scope_modified()  { _git_scope_render_with_type "$(_git_scope_collect modified "$@")"; }
_git_scope_all()       { _git_scope_render_with_type "$(_git_scope_collect all "$@")"; }
_git_scope_untracked() { _git_scope_render_with_type "$(_git_scope_collect untracked "$@")"; }

# ─────────────────────────────────────────────────────────────
# _git_scope_commit - Show detailed information of a git commit
#
# Unlike other git-scope commands (e.g., `staged`, `tracked`), which operate
# on the working directory or index, this command analyzes a historical commit
# and renders its metadata, commit message, changed files, and optionally
# prints the file contents if they are retrievable from HEAD or working tree.
#
# Features:
#   • Displays commit hash, author, date, and message with formatting
#   • Parses both name-status and numstat to show per-file diff counts
#   • Computes total lines added and deleted across all files
#   • Renders affected directory structure using `tree --fromfile`
#   • Supports `-p` to print file contents (text or binary placeholder)
#
# Usage:
#   git-scope commit <commit-ish> [-p]
#
# Example:
#   git-scope commit HEAD~1         # Show summary of an old commit
#   git-scope commit a1b2c3 -p      # Show and print files changed in a commit
#
# Note:
#   Internally, it isolates display output from file path data, ensuring
#   clean separation of UI and logic. It uses a temporary file to pass
#   changed file paths from the rendering function back to the dispatcher.
#
# This command is especially useful for code review, audit trails, or
# inspecting past changes in high detail.
# ─────────────────────────────────────────────────────────────
_git_scope_commit() {
  typeset commit="$1"
  if [[ -z "$commit" ]]; then
    printf "❗ Usage: git-scope commit <commit-hash | HEAD>\n"
    return 1
  fi

  _git_scope_print_commit_metadata "$commit"
  _git_scope_print_commit_message "$commit"
  _git_scope_render_commit_files "$commit"

  typeset -a file_list
  file_list=("${(@f)$(< /tmp/.git-scope-filelist)}")

  if [[ "$_git_scope_should_print" == true ]]; then
    printf "\n📦 Printing file contents:\n"
    for file in "${file_list[@]}"; do
      print_file_content "$file"
      printf "\n"
    done
  fi
}



# Print commit header info (hash, author, date)
_git_scope_print_commit_metadata() {
  typeset commit="$1"

  printf "\n"
  git log -1 --date=format:'%Y-%m-%d %H:%M:%S %z' \
    --pretty=format:"🔖 %C(bold blue)%h%Creset %s%n👤 %an <%ae>%n📅 %ad" "$commit"
}

# Pretty print commit message body
_git_scope_print_commit_message() {
  typeset commit="$1"

  printf "\n\n📝 Commit Message:\n"
  git log -1 --pretty=format:%B "$commit" | awk '
    NR==1 { print "   " $0; print ""; next }
    NF > 0 { print "   " $0 }'
}

# Render file change list with color and stats
_git_scope_render_commit_files() {
  typeset commit="$1"
  typeset -a file_list=()

  typeset ns_lines numstat_lines
  ns_lines=$(git show --pretty=format: --name-status "$commit")
  numstat_lines=$(git show --pretty=format: --numstat "$commit")

  if [[ -z "$ns_lines" || -z "$numstat_lines" ]]; then
    printf "\n📄 Changed files:\n"
    printf "  ⚠️  Merge commit detected — no file-level diff shown by default\n"
    return
  fi

  typeset total_add=0 total_del=0

  printf "\n📄 Changed files:\n"

  while IFS=$'\t' read -r kind file; do
    [[ -z "$file" ]] && continue
    file_list+=("$file")

    typeset add="-"
    typeset del="-"
    typeset match_line=""
    match_line=$(printf "%s\n" "$numstat_lines" | awk -v f="$file" -F'\t' '$3 == f { print $1 "\t" $2; exit }')

    if [[ -n "$match_line" ]]; then
      add=$(cut -f1 <<< "$match_line")
      del=$(cut -f2 <<< "$match_line")
      [[ "$add" != "-" ]] && total_add=$((total_add + add))
      [[ "$del" != "-" ]] && total_del=$((total_del + del))
    fi

    typeset color="$(_git_scope_kind_color "$kind")"
    printf "  %b➤ [%s] %s  [+%s / -%s]%b\n" "$color" "$kind" "$file" "$add" "$del" '\033[0m'
  done <<< "$ns_lines"

  printf "\n  📊 Total: +%d / -%d\n" "$total_add" "$total_del"
  _git_scope_render_tree "${(F)file_list}"

  printf "%s\n" "${file_list[@]}" > /tmp/.git-scope-filelist
}

# Main entry point
git-scope() {
  if ! git rev-parse --git-dir > /dev/null 2>&1; then
    printf "⚠️ Not a Git repository. Run this command inside a Git project.\n"
    return 1
  fi

  typeset sub="$1"
  shift

  # Detect -p flag (print file content)
  _git_scope_should_print=false
  typeset -a args=()
  for arg in "$@"; do
    if [[ "$arg" == "-p" || "$arg" == "--print" ]]; then
      _git_scope_should_print=true
    else
      args+=("$arg")
    fi
  done

  case "$sub" in
    tracked)
      _git_scope_tracked "${args[@]}" ;;
    staged)
      _git_scope_staged "${args[@]}" ;;
    modified)
      _git_scope_modified "${args[@]}" ;;
    all)
      _git_scope_all "${args[@]}" ;;
    untracked)
      _git_scope_untracked "${args[@]}" ;;
    commit)
      _git_scope_commit "${args[@]}" ;;
    help|-h|--help|"")
      printf "Usage: git-scope <command> [args...]\n"
      printf "Commands:\n"
      printf "  tracked     Show files tracked by Git (optionally filtered by prefix)\n"
      printf "  staged      Show files staged for commit\n"
      printf "  modified    Show unstaged modified files\n"
      printf "  all         Show all changes (staged + unstaged)\n"
      printf "  untracked   Show untracked files\n"
      printf "  commit <id> Show detailed info for a given commit (use -p to print content)\n"
      ;;
    *)
      printf "⚠️ Unknown subcommand: '%s'\n" "$sub"
      return 1 ;;
  esac
}
