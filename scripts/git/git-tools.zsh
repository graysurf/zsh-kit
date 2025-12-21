# ────────────────────────────────────────────────────────
# Aliases and Unalias
# ────────────────────────────────────────────────────────
if command -v safe_unalias >/dev/null; then
  safe_unalias \
    gr grs grm grh \
    gbh gbc gdb \
    gdc groot \
    gop god goc gob \
    gh-open \
    gh-open-branch \
    gh-open-default-branch \
    gh-open-commit \
    gh-push-open \
    git-commit-context gcc \
    git-reset-hard \
    git-reset-soft \
    git-reset-mixed \
    git-reset-undo \
    git-back-head \
    git-back-checkout \
    git-delete-merged-branches \
    git-zip \
    get_commit_hash
fi

# ────────────────────────────────────────────────────────
# Git operation aliases
# ────────────────────────────────────────────────────────

# Export current HEAD as zip file named by short hash (e.g. backup-a1b2c3d.zip)
alias git-zip='git archive --format zip HEAD -o "backup-$(git rev-parse --short HEAD).zip"'

# Reset staged files (equivalent to "git reset")
alias gr='git reset'

# Copy staged diff to clipboard (default) or print to stdout for LLM usage.
gdc() {
  typeset diff mode
  typeset -i mode_flags=0
  typeset -a extra_args=()
  mode="clipboard"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --stdout|-p|--print)
        mode="stdout"
        (( mode_flags++ ))
        ;;
      --both)
        mode="both"
        (( mode_flags++ ))
        ;;
      --help|-h)
        print "Usage: gdc [--stdout|--both]"
        print "  --stdout   Print staged diff to stdout (no status message)"
        print "  --both     Print to stdout and copy to clipboard"
        return 0
        ;;
      *)
        extra_args+=("$1")
        ;;
    esac
    shift
  done

  if (( mode_flags > 1 )); then
    print -u2 -r -- "❗ Only one output mode is allowed: --stdout or --both"
    return 1
  fi

  if (( ${#extra_args[@]} > 0 )); then
    print -u2 -r -- "❗ Unknown argument: ${extra_args[1]}"
    print -u2 -r -- "Usage: gdc [--stdout|--both]"
    return 1
  fi

  diff=$(git diff --cached --no-color)

  if [[ -z "$diff" ]]; then
    print "⚠️  No staged changes to copy"
    return 1
  fi

  if [[ "$mode" == "stdout" ]]; then
    printf "%s\n" "$diff"
    return 0
  fi

  printf "%s" "$diff" | set_clipboard

  if [[ "$mode" == "both" ]]; then
    printf "%s\n" "$diff"
  fi

  print "✅ Staged diff copied to clipboard"
}

# Jump to the root directory of the current Git repository
groot() {
  typeset root
  root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    print "❌ Not in a git repository"
    return 1
  }
  cd "$root" && print "\n 📁 Jumped to Git root: $root"
}

# get_commit_hash <ref>
get_commit_hash() {
  typeset ref="$1"
  if [[ -z "$ref" ]]; then
    print "❌ Missing git ref" >&2
    return 1
  fi

  # Try resolve commit (handles annotated tags too)
  git rev-parse --verify --quiet "${ref}^{commit}"
}

# ────────────────────────────────────────────────────────
# Git workflow helper functions
# ────────────────────────────────────────────────────────

# Undo the last commit while keeping all changes staged (soft reset)
#
# This function performs a `git reset --soft HEAD~1`, which removes the
# last commit from history but keeps all changes staged. This is useful
# when you want to rewrite the commit message or make additional edits
# before recommitting.
#
# It is a safer alternative to hard resets and preserves your working state.
git-reset-soft() {
  print "⚠️  This will rewind your last commit (soft reset)"
  print "🧠 Your changes will remain STAGED. Useful for rewriting commit message."
  print -n "❓ Proceed with 'git reset --soft HEAD~1'? [y/N] "
  read -r confirm
  if [[ "$confirm" != [yY] ]]; then
    print "🚫 Aborted"
    return 1
  fi

  git reset --soft HEAD~1
  print "✅ Last commit undone. Your changes are still staged."
}

# Hard reset to the previous commit with confirmation (DANGEROUS)
#
# This function performs a `git reset --hard HEAD~1`, which removes the last
# commit and discards all staged and unstaged changes in the working tree.
# 
# ⚠️ WARNING: This operation is destructive and cannot be undone.
# Only use it when you are absolutely sure you want to discard local changes.
git-reset-hard() {
  print "⚠️  This will HARD RESET your repository to the previous commit."
  print "🔥 All staged and unstaged changes will be PERMANENTLY LOST."
  print "🧨 This is equivalent to: git reset --hard HEAD~1"
  print -n "❓ Are you absolutely sure? [y/N] "
  read -r confirm
  if [[ "$confirm" != [yY] ]]; then
    print "🚫 Aborted"
    return 1
  fi

  git reset --hard HEAD~1
  print "✅ Hard reset completed. Your working directory is now clean."
}

# Undo the last commit and unstage all changes (mixed reset)
#
# This function performs a `git reset --mixed HEAD~1`, which removes the
# last commit and moves all associated changes into the working directory
# in an unstaged state. This is useful when you want to revise changes
# more freely before recommitting.
#
# This is Git's default reset mode if no flag is given.
git-reset-mixed() {
  print "⚠️  This will rewind your last commit (mixed reset)"
  print "🧠 Your changes will become UNSTAGED and editable in working directory."
  print "❓ Proceed with 'git reset --mixed HEAD~1'? [y/N] "
  read -r confirm
  if [[ "$confirm" != [yY] ]]; then
    print "🚫 Aborted"
    return 1
  fi

  git reset --mixed HEAD~1
  print "✅ Last commit undone. Your changes are now unstaged."
}

# Undo the last `git reset --hard` by restoring previous HEAD state
#
# This function resets the repository to the previous HEAD using
# `git reset --hard HEAD@{1}`. It is useful when you've recently run
# a destructive `git reset --hard` command and want to recover the
# state before that reset — including working directory and staging area.
#
# Unlike `git-back-head()` or `git-back-checkout()`, which are non-destructive
# and only move HEAD, this operation fully restores the previous commit state,
# overwriting all uncommitted changes.
git-reset-undo() {
  typeset prev_commit
  prev_commit=$(git rev-parse HEAD@{1} 2>/dev/null)

  if [[ -z "$prev_commit" ]]; then
    print "❌ Cannot resolve HEAD@{1}."
    return 1
  fi

  print "🕰  Attempting to undo the last hard reset..."
  print "📜 This will reset your repository back to:"
  git log --oneline -1 "$prev_commit"
  print -n "❓ Proceed with 'git reset --hard HEAD@{1}'? [y/N] "
  read -r confirm
  if [[ "$confirm" != [yY] ]]; then
    print "🚫 Aborted"
    return 1
  fi

  git reset --hard HEAD@{1}
  print "✅ Repository reset back to previous HEAD: $prev_commit"
}

# Rewind HEAD to its previous position with confirmation
#
# This function uses `git rev-parse HEAD@{1}` to retrieve the previous
# position of HEAD from the reflog. It is useful when you have recently
# moved HEAD by mistake (e.g., via a reset, commit, or other action),
# and want to undo that movement without affecting your working tree.
#
# Unlike `git-back-checkout()`, which targets the previous checkout action specifically,
# this function restores HEAD to whatever state it was in before the last
# movement — not limited to checkouts.
git-back-head() {
  typeset prev_head
  prev_head=$(git rev-parse HEAD@{1} 2>/dev/null)

  if [[ -z "$prev_head" ]]; then
    print "❌ Cannot find previous HEAD in reflog."
    return 1
  fi

  print "⏪ This will move HEAD back to the previous position:"
  print "🔁 $(git log --oneline -1 "$prev_head")"
  print -n "❓ Proceed with 'git checkout HEAD@{1}'? [y/N] "
  read -r confirm
  if [[ "$confirm" != [yY] ]]; then
    print "🚫 Aborted"
    return 1
  fi

  git checkout "$prev_head"
  print "✅ Restored to previous HEAD: $prev_head"
}

# Restore HEAD to previous checkout branch (avoids detached HEAD)
# This finds the last checkout operation that moved from a branch to another branch,
# skipping over cases where you checked out a commit SHA.
git-back-checkout() {
  typeset current_branch from_branch

  current_branch=$(git rev-parse --abbrev-ref HEAD)

  from_branch=$(
    git reflog |
      grep "checkout: moving from " |
      grep "to $current_branch" |
      sed -n 's/.*moving from \([^ ]*\) to '"$current_branch"'/\1/p' |
      head -n 1
  )

  if [[ -z "$from_branch" ]]; then
    print "❌ Could not find a previous branch that switched to $current_branch."
    return 1
  fi

  print "⏪ This will move HEAD back to previous branch: $from_branch"
  print -n "❓ Proceed with 'git checkout $from_branch'? [y/N] "
  read -r confirm
  if [[ "$confirm" != [yY] ]]; then
    print "🚫 Aborted"
    return 1
  fi

  git checkout "$from_branch"
  print "✅ Restored to previous branch: $from_branch"
}

# Delete local branches that are already merged, with confirmation.
#
# This function lists local branches merged into a base ref (default: HEAD),
# then asks for confirmation before deleting them using `git branch -d`.
# It protects the current branch, the base ref (and its local name if applicable),
# and common mainline branches (main/master/develop/trunk).
#
# Usage:
#   git-delete-merged-branches
#   git-delete-merged-branches -b main
git-delete-merged-branches() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset base_ref='HEAD'
  typeset base_local=''
  typeset confirm=''
  typeset current_branch=''
  typeset branch=''
  typeset name=''
  typeset base_commit=''
  typeset head_commit=''
  typeset delete_flag='-d'
  typeset -a protected_branches=(main master develop trunk)
  typeset -a merged_branches=()
  typeset -a candidates=()
  typeset -A protected_set=()
  typeset -A opts=()

  if ! zmodload zsh/zutil 2>/dev/null; then
    print -u2 -r -- "❌ zsh/zutil module is required for option parsing"
    return 1
  fi
  zparseopts -D -E -A opts -- h -help b: -base:

  if (( ${+opts[-h]} || ${+opts[--help]} )); then
    print -r -- "Usage: git-delete-merged-branches [-b|--base <ref>]"
    print -r -- "  -b, --base <ref>  Base ref used to determine merged branches (default: HEAD)"
    return 0
  fi

  if (( ${+opts[-b]} )); then
    base_ref="${opts[-b]}"
  elif (( ${+opts[--base]} )); then
    base_ref="${opts[--base]}"
  fi

  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    print -u2 -r -- "❌ Not in a git repository"
    return 1
  }

  git rev-parse --verify --quiet "$base_ref" >/dev/null || {
    print -u2 -r -- "❌ Invalid base ref: $base_ref"
    return 1
  }

  base_commit=$(git rev-parse "${base_ref}^{commit}" 2>/dev/null) || {
    print -u2 -r -- "❌ Unable to resolve base commit: $base_ref"
    return 1
  }
  head_commit=$(git rev-parse HEAD 2>/dev/null) || {
    print -u2 -r -- "❌ Unable to resolve HEAD commit"
    return 1
  }
  if [[ "$base_commit" != "$head_commit" ]]; then
    delete_flag='-D'
  fi

  current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || {
    print -u2 -r -- "❌ Unable to resolve current branch"
    return 1
  }

  for name in "${protected_branches[@]}"; do
    protected_set[$name]=1
  done
  if [[ -n "$current_branch" && "$current_branch" != 'HEAD' ]]; then
    protected_set[$current_branch]=1
  fi
  protected_set[$base_ref]=1
  if git show-ref --verify --quiet "refs/remotes/$base_ref"; then
    base_local="${base_ref#*/}"
  elif git show-ref --verify --quiet "refs/heads/$base_ref"; then
    base_local="$base_ref"
  fi
  if [[ -n "$base_local" ]]; then
    protected_set[$base_local]=1
  fi

  merged_branches=(${(f)$(git for-each-ref --merged "$base_ref" --format='%(refname:short)' refs/heads)})

  if (( ${#merged_branches[@]} == 0 )); then
    print -r -- "✅ No merged local branches found."
    return 0
  fi

  for branch in "${merged_branches[@]}"; do
    if (( ${+protected_set[$branch]} )); then
      continue
    fi
    candidates+=("$branch")
  done

  if (( ${#candidates[@]} == 0 )); then
    print -r -- "✅ No deletable merged branches."
    return 0
  fi

  print -r -- "🧹 Merged branches to delete (base: $base_ref):"
  printf '  - %s\n' "${candidates[@]}"
  print -n -r -- "❓ Proceed with deleting these branches? [y/N] "
  read -r confirm
  if [[ "$confirm" != [yY] ]]; then
    print -r -- "🚫 Aborted"
    return 1
  fi

  for branch in "${candidates[@]}"; do
    git branch "$delete_flag" -- "$branch"
  done

  print -r -- "✅ Deleted merged branches."
}

alias gdb='git-delete-merged-branches'

# ────────────────────────────────────────────────────────
# GitHub / GitLab remote open helpers
# ────────────────────────────────────────────────────────

# git-resolve-upstream
# Resolve the remote/branch pair backing the current HEAD (prints remote then branch).
git-resolve-upstream() {
  emulate -L zsh
  setopt localoptions

  typeset fallback_remote='origin' branch='' upstream='' remote='' remote_branch=''

  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || {
    print -r -- "❌ Unable to resolve current branch" >&2
    return 1
  }

  upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)
  if [[ -n "$upstream" && "$upstream" != "$branch" ]]; then
    remote="${upstream%%/*}"
    remote_branch="${upstream#*/}"
  fi

  if [[ -z "$remote" ]]; then
    remote="$fallback_remote"
  fi

  if [[ -z "$remote_branch" || "$remote_branch" == "$upstream" || "$remote_branch" == 'HEAD' ]]; then
    remote_branch="$branch"
  fi

  print -r -- "$remote"
  print -r -- "$remote_branch"
}

# git-normalize-remote-url <remote>
# Convert a Git remote URL to an https form suitable for browsers and print it.
git-normalize-remote-url() {
  emulate -L zsh
  setopt localoptions

  typeset remote="$1"
  typeset raw_url='' normalized=''

  if [[ -z "$remote" ]]; then
    print -r -- "❌ git-normalize-remote-url requires remote name" >&2
    return 1
  fi

  raw_url=$(git remote get-url "$remote" 2>/dev/null) || {
    print -r -- "❌ Failed to resolve remote URL for $remote" >&2
    return 1
  }

  normalized=$(printf '%s\n' "$raw_url" | sed \
    -e 's/^git@/https:\/\//' \
    -e 's/com:/com\//' \
    -e 's/\.git$//' \
    -e 's/^ssh:\/\///' \
    -e 's/^https:\/\/git@/https:\/\//')

  if [[ -z "$normalized" ]]; then
    print -r -- "❌ Unable to normalize remote URL for $remote" >&2
    return 1
  fi

  print -r -- "$normalized"
}

# Open the repository page on GitHub or GitLab
gh-open() {
  emulate -L zsh
  setopt localoptions
  typeset -a upstream=()
  typeset remote='' remote_branch='' url=''

  upstream=(${(@f)$(git-resolve-upstream)}) || return 1
  if (( ${#upstream[@]} < 2 )); then
    print -r -- "❌ Failed to resolve upstream information" >&2
    return 1
  fi
  remote="${upstream[1]}"
  remote_branch="${upstream[2]}"

  url=$(git-normalize-remote-url "$remote") || return 1

  if command -v open &>/dev/null; then
    open "$url"
  elif command -v xdg-open &>/dev/null; then
    xdg-open "$url"
  else
    print -r -- "❌ Cannot open URL (no open/xdg-open)"
    return 1
  fi

  print -r -- "🌐 Opened: $url"
}

# Short aliases for common undo/reset operations
alias grs='git-reset-soft'
alias grm='git-reset-mixed'
alias grh='git-reset-hard'
alias gbh='git-back-head'
alias gbc='git-back-checkout'

# Open the current branch page on GitHub or GitLab
gh-open-branch() {
  emulate -L zsh
  setopt localoptions
  typeset -a upstream=()
  typeset remote='' remote_branch='' url='' target_url=''

  upstream=(${(@f)$(git-resolve-upstream)}) || return 1
  if (( ${#upstream[@]} < 2 )); then
    print -r -- "❌ Failed to resolve upstream information" >&2
    return 1
  fi
  remote="${upstream[1]}"
  remote_branch="${upstream[2]}"

  url=$(git-normalize-remote-url "$remote") || return 1

  target_url="$url/tree/$remote_branch"

  if command -v open &>/dev/null; then
    open "$target_url"
  elif command -v xdg-open &>/dev/null; then
    xdg-open "$target_url"
  else
    print -r -- "❌ Cannot open URL (no open/xdg-open)"
    return 1
  fi

  print -r -- "🌿 Opened: $target_url"
}

# Open a specific commit on GitHub (supports tag, branch, or commit hash)
gh-open-commit() {
  emulate -L zsh
  setopt localoptions
  typeset hash="${1:-HEAD}"
  typeset -a upstream=()
  typeset remote='' remote_branch='' url='' commit=''

  upstream=(${(@f)$(git-resolve-upstream)}) || return 1
  if (( ${#upstream[@]} < 2 )); then
    print -r -- "❌ Failed to resolve upstream information" >&2
    return 1
  fi
  remote="${upstream[1]}"
  remote_branch="${upstream[2]}"

  url=$(git-normalize-remote-url "$remote") || return 1

  if [[ "$url" != https://github.com/* ]]; then
    print -r -- "❗ Only GitHub URLs are supported."
    return 1
  fi

  # Ensure annotated tag resolves to commit, not tag object
  commit=$(git rev-parse "${hash}^{commit}" 2>/dev/null) || {
    print -r -- "❌ Invalid commit/tag/branch: $hash"
    return 1
  }

  typeset commit_url="$url/commit/$commit"
  print -r -- "🔗 Opening: $commit_url"

  if command -v open &>/dev/null; then
    open "$commit_url"
  elif command -v xdg-open &>/dev/null; then
    xdg-open "$commit_url"
  else
    print -r -- "❌ Cannot open URL (no open/xdg-open)"
    return 1
  fi
}

# Open default branch (main or master)
gh-open-default-branch() {
  emulate -L zsh
  setopt localoptions
  typeset -a upstream=()
  typeset remote='' remote_branch='' url='' default_branch=''

  upstream=(${(@f)$(git-resolve-upstream)}) || return 1
  if (( ${#upstream[@]} < 2 )); then
    print -r -- "❌ Failed to resolve upstream information" >&2
    return 1
  fi
  remote="${upstream[1]}"
  remote_branch="${upstream[2]}"

  url=$(git-normalize-remote-url "$remote") || return 1

  default_branch=$(git remote show "$remote" 2>/dev/null | awk '/HEAD branch/ {print $NF}')

  if [[ -z "$default_branch" ]]; then
    print -r -- "❌ Failed to resolve default branch for $remote"
    return 1
  fi

  typeset target_url="$url/tree/$default_branch"

  if command -v open &>/dev/null; then
    open "$target_url"
  elif command -v xdg-open &>/dev/null; then
    xdg-open "$target_url"
  else
    print -r -- "❌ Cannot open URL (no open/xdg-open)"
    return 1
  fi

  print -r -- "🌿 Opened: $target_url"
}

# Open the repository page on GitHub or GitLab
alias gop='gh-open'

# Open default branch
alias god='gh-open-default-branch'

# Open current HEAD commit
alias goc='gh-open-commit'

# Open current working branch
alias gob='gh-open-branch'

# Push current branch and open the pushed commit on GitHub or GitLab
gh-push-open() {
  git push "$@" || return $?
  gh-open-commit HEAD
}

# git-commit-context
#
# This function generates a comprehensive Markdown-formatted summary of the current staged Git changes,
# to assist with writing a precise and valid commit message (especially for use with commitlint rules).
#
# It performs the following steps:
#  1. Collects the full diff of staged files (`git diff --cached`).
#  2. Generates a file scope summary and directory tree using `git-scope staged`.
#  3. Iterates through each staged file to include its staged (index) version (after changes).
#     - For deleted files: notes that index content is unavailable.
#     - For added/modified/renamed files: includes the staged content.
#  4. Formats all this into a Markdown document, including:
#     - 📄 Git staged diff (as `diff` block)
#     - 📂 Scope and directory tree (as `bash` block)
#     - 📚 Staged file contents (as `ts` blocks per file)
#
# The result is piped to both:
#  - `set_clipboard` for immediate pasting into ChatGPT or documentation tools.
#  - A temporary file via `mktemp` for future reference/debugging.
#
# ⚠️ The resulting document also includes instructions for generating Semantic Commit messages
#     that follow commitlint standards.
#
# Example usage:
#   $ git add .
#   $ git-commit-context-md
#
# Output: Markdown commit context is copied to clipboard and logged to a temp file.
git-commit-context () {
  emulate -L zsh
  setopt localoptions pipe_fail

  typeset tmpfile='' diff='' scope='' contents='' mode='clipboard'
  typeset no_color=false
  typeset -a extra_args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --stdout|-p|--print)
        mode="stdout"
        ;;
      --both)
        mode="both"
        ;;
      --no-color|no-color)
        no_color=true
        ;;
      --help|-h)
        print -r -- "Usage: git-commit-context [--stdout|--both] [--no-color]"
        print -r -- "  --stdout   Print commit context to stdout only"
        print -r -- "  --both     Print to stdout and copy to clipboard"
        print -r -- "  --no-color Disable ANSI colors (also via NO_COLOR)"
        return 0
        ;;
      *)
        extra_args+=("$1")
        ;;
    esac
    shift
  done

  diff="$(git diff --cached --no-color)"

  if (( ${#extra_args[@]} > 0 )); then
    print -u2 -r -- "⚠️  Ignoring unknown arguments: ${extra_args[*]}"
  fi

  if [[ -z "$diff" ]]; then
    printf "⚠️  No staged changes to record\n" >&2
    return 1
  fi

  typeset -a scope_args=(staged)
  if [[ "$no_color" == true || -n "${NO_COLOR-}" ]]; then
    scope_args+=(--no-color)
  fi
  scope="$(git-scope "${scope_args[@]}" | sed 's/\x1b\[[0-9;]*m//g')"

  tmpfile="$(mktemp -t commit-context.md.XXXXXX)"

  contents="$(
    git -c core.quotepath=false diff --cached --name-status -z | while IFS= read -r -d '' fstatus; do
      typeset file='' newfile=''

      if [[ -z "$fstatus" ]]; then
        continue
      fi

      case "$fstatus" in
        R*|C*)
          IFS= read -r -d '' file || break
          IFS= read -r -d '' newfile || break
          ;;
        *)
          IFS= read -r -d '' file || break
          ;;
      esac

      display_path="$file"
      content_path="$file"

      if [[ -n "$newfile" ]]; then
        display_path="${file} -> ${newfile}"
        content_path="$newfile"
      fi

      printf "### %s (%s)\n\n" "$display_path" "$fstatus"

      if [[ "$fstatus" == "D" ]]; then
        if git cat-file -e "HEAD:$file" 2>/dev/null; then
          printf "[Deleted file, showing HEAD version]\n\n"
          printf '```ts\n'
          git show "HEAD:$file" 2>/dev/null || printf '[HEAD version not found]\n'
          printf '```\n\n'
        else
          printf "[Deleted file, no HEAD version found]\n\n"
        fi
      elif [[ "$fstatus" == "A" || "$fstatus" == "M" || "$fstatus" == R* || "$fstatus" == C* ]]; then
        printf '```ts\n'
        git show :"$content_path" 2>/dev/null || printf '[Index version not found]\n'
        printf '```\n\n'
      else
        printf "[Unhandled status: %s]\n\n" "$fstatus"
      fi
    done
  )"

  printf "%s\n" "# Commit Context

## Input expectations

- Full-file reads are not required for commit message generation.
- Base the message on staged diff, scope tree, and staged (index) version content.

---

## 📂 Scope and file tree:

\`\`\`text
$scope
\`\`\`

## 📄 Git staged diff:

\`\`\`diff
$diff
\`\`\`

## 📚 Staged file contents (index version):

$contents" > "$tmpfile"

  if [[ "$mode" == "stdout" ]]; then
    command cat "$tmpfile"
    return 0
  fi

  if [[ "$mode" == "both" ]]; then
    command cat "$tmpfile"
  fi

  command cat "$tmpfile" | set_clipboard

  if [[ "$mode" == "clipboard" ]]; then
    printf "✅ Commit context copied to clipboard with:\n"
    printf "  • Diff\n"
    printf "  • Scope summary (via git-scope staged)\n"
    printf "  • Staged file contents (index version)\n"
  fi
}

alias gcc='git-commit-context'
