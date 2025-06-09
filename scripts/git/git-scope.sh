# ───────────────────────────────────────────────
# git-scope - Git scope viewer unified CLI
# Usage: git-scope <command> [args...]
# ───────────────────────────────────────────────

# Render file list with A/M/D tags and color, then show tree
_git_scope_render_with_type() {
  typeset input="$1"

  if [[ -z "$input" ]]; then
    echo "⚠️  No matching files"
    return 1
  fi

  typeset COLOR_RESET='\033[0m'
  typeset ADDED='\033[1;32m'
  typeset MODIFIED='\033[1;33m'
  typeset DELETED='\033[1;31m'
  typeset OTHER='\033[1;34m'

  echo -e "\n📄 Changed files:"

  typeset tree_files=""
  echo "$input" | while IFS=$'\t' read -r kind file; do
    [[ -z "$file" ]] && continue

    typeset color="$OTHER"
    case "$kind" in
      A) color="$ADDED" ;;
      M) color="$MODIFIED" ;;
      D) color="$DELETED" ;;
      U) color="$OTHER" ;;
      -) color="$COLOR_RESET" ;;
    esac

    echo -e "  ${color}➤ [$kind] $file${COLOR_RESET}"
    tree_files+="$file"$'\n'
  done

  echo -e "\n📂 Directory tree:"
  echo "$tree_files" | awk -F/ '{
    path=""
    for(i=1;i<NF;i++) {
      path = (path ? path "/" $i : $i)
      print path
    }
    print $0
  }' | sort -u | tree --fromfile -C
}

_git_scope_tracked() {
  echo -e "\n📂 Show full directory tree of all files tracked by Git (excluding ignored/untracked)\n"

  typeset files
  files=$(git ls-files)

  if [[ -z "$files" ]]; then
    echo "📭 No tracked files in working directory"
    return 1
  fi

  typeset marked=""
  while IFS= read -r file; do
    marked+="-\t${file}"$'\n'
  done <<< "$files"

  _git_scope_render_with_type "$marked"
}

_git_scope_staged() {
  echo -e "\n📂 Show tree of staged files (ready to be committed)\n"
  typeset ns_lines
  ns_lines=$(git diff --cached --name-status --diff-filter=ACMRTUXB)

  _git_scope_render_with_type "$ns_lines"
}

_git_scope_modified() {
  echo -e "\n📂 Show tree of modified files (not yet staged)\n"
  typeset ns_lines
  ns_lines=$(git diff --name-status --diff-filter=ACMRTUXB)

  _git_scope_render_with_type "$ns_lines"
}

_git_scope_all() {
  echo -e "\n📂 Show tree of all changed files (staged + modified)\n"
  typeset staged modified
  staged=$(git diff --cached --name-status --diff-filter=ACMRTUXB)
  modified=$(git diff --name-status --diff-filter=ACMRTUXB)

  typeset combined
  combined=$(printf "%s\n%s" "$staged" "$modified" | grep -v '^$' | sort -u)

  _git_scope_render_with_type "$combined"
}

_git_scope_untracked() {
  echo -e "\n📂 Show tree of untracked files (new files not yet added)\n"
  typeset files
  files=$(git ls-files --others --exclude-standard)

  if [[ -z "$files" ]]; then
    echo "📭 No untracked files"
    return 1
  fi

  typeset marked=""
  while IFS= read -r file; do
    marked+="U\t${file}"$'\n'
  done <<< "$files"

  _git_scope_render_with_type "$marked"
}

_git_scope_commit() {
  typeset commit="$1"
  if [[ -z "$commit" ]]; then
    echo "❗ Usage: git-scope commit <commit-hash | HEAD>"
    return 1
  fi

  typeset COLOR_RESET='\033[0m'
  typeset ADDED='\033[1;32m'
  typeset MODIFIED='\033[1;33m'
  typeset DELETED='\033[1;31m'
  typeset OTHER='\033[1;34m'

  echo ""
  git log -1 --date=format:'%Y-%m-%d %H:%M:%S %z' \
    --pretty=format:"🔖 %C(bold blue)%h%Creset %s%n👤 %an <%ae>%n📅 %ad" "$commit"

  echo -e "\n📝 Commit Message:"
  git log -1 --pretty=format:%B "$commit" | awk '
    NR==1 { print "   " $0; print ""; next }
    NF > 0 { print "   " $0 }'
  
  echo -e "\n📄 Changed files:"

typeset ns_lines
ns_lines=$(git show --pretty=format: --name-status "$commit")
typeset numstat_lines
numstat_lines=$(git show --pretty=format: --numstat "$commit")

if [[ -z "$ns_lines" || -z "$numstat_lines" ]]; then
  echo "  ⚠️  Merge commit detected — no file-level diff shown by default"
else
  typeset total_add=0
  typeset total_del=0

  while IFS=$'\t' read -r kind file; do
    typeset add="-"
    typeset del="-"

    unset match_line
    match_line=$(echo "$numstat_lines" | awk -v f="$file" -F'\t' '$3 == f { print $1 "\t" $2; exit }')

    if [[ -n "$match_line" ]]; then
      add=$(echo "$match_line" | cut -f1)
      del=$(echo "$match_line" | cut -f2)

      [[ "$add" != "-" ]] && total_add=$((total_add + add))
      [[ "$del" != "-" ]] && total_del=$((total_del + del))
    fi

    typeset color="$OTHER"
    case "$kind" in
      A) color="$ADDED" ;;
      M) color="$MODIFIED" ;;
      D) color="$DELETED" ;;
    esac

    echo -e "  ${color} ➤ [$kind] $file  [+${add} / -${del}]${COLOR_RESET}"
  done <<< "$ns_lines"

  echo -e "\n  📊 Total: +$total_add / -$total_del"
fi

  echo -e "\n📂 Directory tree:"
  git show --pretty=format: --name-only "$commit" | awk -F/ '{
    path = ""
    for (i = 1; i < NF; i++) {
      path = (path ? path "/" $i : $i)
      print path
    }
    print $0
  }' | sort -u | tree --fromfile -C
}

git-scope() {
  if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❗ Not a Git repository. Run this command inside a Git project."
    return 1
  fi

  typeset sub="$1"
  shift

  case "$sub" in
    ""|track|tracked)
      _git_scope_tracked "$@" ;;
    staged)
      _git_scope_staged "$@" ;;
    modified)
      _git_scope_modified "$@" ;;
    all)
      _git_scope_all "$@" ;;
    untracked)
      _git_scope_untracked "$@" ;;
    commit)
      _git_scope_commit "$@" ;;
    help|-h|--help)
      echo "Usage: git-scope <command> [args...]"
      echo ""
      echo "Commands:"
      echo "  (default)         Tracked file tree (git ls-files)"
      echo "  staged            Staged files (git diff --cached)"
      echo "  modified          Modified files (not staged)"
      echo "  all               All changed files (staged + modified)"
      echo "  untracked         New untracked files"
      echo "  commit <hash>     Show a specific commit's changes"
      echo ""
      return 0 ;;
    *)
      echo "❗ Unknown subcommand: '$sub'"
      echo "Run 'git-scope help' for usage."
      return 1 ;;
  esac
}
