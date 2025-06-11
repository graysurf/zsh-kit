# ────────────────────────────────────────────────────────
# Unalias to avoid redefinition
# ────────────────────────────────────────────────────────

safe_unalias                    \
  gr grs grm grh                \
  gbh gbc                       \
  gdc groot                     \
  gop god goc gob               \
  gh-open                       \
  gh-open-branch                \
  gh-open-default-branch        \
  gh-open-commit                \
  gh-push-open                  \
  git-commit-context gcc        \
  git-reset-hard                \
  git-reset-soft                \
  git-reset-mixed               \
  git-reset-undo                \
  git-back-head                 \
  git-back-checkout             \
  git-zip                       \
  get_commit_hash               \
  2>/dev/null

# ────────────────────────────────────────────────────────
# Git operation aliases
# ────────────────────────────────────────────────────────

# Export current HEAD as zip file named by short hash (e.g. backup-a1b2c3d.zip)
alias git-zip='git archive --format zip HEAD -o "backup-$(git rev-parse --short HEAD).zip"'

# Reset staged files (equivalent to "git reset")
alias gr='git reset'

# Copy staged diff to clipboard (no output)
gdc() {
  typeset diff
  diff=$(git diff --cached --no-color)

  if [[ -z "$diff" ]]; then
    echo "⚠️  No staged changes to copy"
    return 1
  fi

  printf "%s" "$diff" | pbcopy
  echo "✅ Staged diff copied to clipboard"
}

# Jump to the root directory of the current Git repository
groot() {
  typeset root
  root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "❌ Not in a git repository"
    return 1
  }
  cd "$root" && echo -e "\n 📁 Jumped to Git root: $root"
}

# get_commit_hash <ref>
get_commit_hash() {
  typeset ref="$1"
  if [[ -z "$ref" ]]; then
    echo "❌ Missing git ref" >&2
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
  echo "⚠️  This will rewind your last commit (soft reset)"
  echo "🧠 Your changes will remain STAGED. Useful for rewriting commit message."
  echo -n "❓ Proceed with 'git reset --soft HEAD~1'? [y/N] "
  read -r confirm
  if [[ "$confirm" != [yY] ]]; then
    echo "🚫 Aborted"
    return 1
  fi

  git reset --soft HEAD~1
  echo "✅ Last commit undone. Your changes are still staged."
}

# Hard reset to the previous commit with confirmation (DANGEROUS)
#
# This function performs a `git reset --hard HEAD~1`, which removes the last
# commit and discards all staged and unstaged changes in the working tree.
# 
# ⚠️ WARNING: This operation is destructive and cannot be undone.
# Only use it when you are absolutely sure you want to discard local changes.
git-reset-hard() {
  echo "⚠️  This will HARD RESET your repository to the previous commit."
  echo "🔥 All staged and unstaged changes will be PERMANENTLY LOST."
  echo "🧨 This is equivalent to: git reset --hard HEAD~1"
  echo -n "❓ Are you absolutely sure? [y/N] "
  read -r confirm
  if [[ "$confirm" != [yY] ]]; then
    echo "🚫 Aborted"
    return 1
  fi

  git reset --hard HEAD~1
  echo "✅ Hard reset completed. Your working directory is now clean."
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
  echo "⚠️  This will rewind your last commit (mixed reset)"
  echo "🧠 Your changes will become UNSTAGED and editable in working directory."
  echo "❓ Proceed with 'git reset --mixed HEAD~1'? [y/N] "
  read -r confirm
  if [[ "$confirm" != [yY] ]]; then
    echo "🚫 Aborted"
    return 1
  fi

  git reset --mixed HEAD~1
  echo "✅ Last commit undone. Your changes are now unstaged."
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
  echo "🕰  Attempting to undo the last hard reset..."
  echo "📜 This will reset your repository back to: HEAD@{1}"
  echo -n "❓ Proceed with git reset --hard HEAD@{1}? [y/N] "
  read -r confirm
  if [[ "$confirm" != [yY] ]]; then
    echo "🚫 Aborted"
    return 1
  fi

  git reset --hard HEAD@{1}
  echo "✅ Repository reset back to previous HEAD (before last reset)."
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
    echo "❌ Cannot find previous HEAD in reflog."
    return 1
  fi

  echo "⏪ This will move HEAD back to the previous position:"
  echo "🔁 $(git log --oneline -1 "$prev_head")"
  echo -n "❓ Proceed with 'git checkout HEAD@{1}'? [y/N] "
  read -r confirm
  if [[ "$confirm" != [yY] ]]; then
    echo "🚫 Aborted"
    return 1
  fi

  git checkout "$prev_head"
  echo "✅ Restored to previous HEAD: $prev_head"
}

# Restore HEAD to the previous checkout location with confirmation
# 
# This function looks up the Git reflog to find the last checkout action
# (e.g., switching branches or checking out a commit), and moves HEAD back
# to that commit. It is useful when you've checked out something temporarily
# and want to return to where you were before.
git-back-checkout() {
  typeset prev_ref
  prev_ref=$(git reflog | awk '/checkout/ {print $1}' | sed -n '2p')

  if [[ -z "$prev_ref" ]]; then
    echo "❌ Cannot find previous checkout location in reflog."
    return 1
  fi

  echo "⏪ This will move HEAD back to the previous checkout position:"
  echo "🔁 $(git log --oneline -1 "$prev_ref")"
  echo -n "❓ Proceed with 'git checkout $prev_ref'? [y/N] "
  read -r confirm
  if [[ "$confirm" != [yY] ]]; then
    echo "🚫 Aborted"
    return 1
  fi

  git checkout "$prev_ref"
  echo "✅ Restored to previous checkout state: $prev_ref"
}

# ────────────────────────────────────────────────────────
# GitHub / GitLab remote open helpers
# ────────────────────────────────────────────────────────

# Open the repository page on GitHub or GitLab
gh-open() {
  typeset url
  url=$(git remote get-url origin 2>/dev/null | sed \
    -e 's/^git@/https:\/\//' \
    -e 's/com:/com\//' \
    -e 's/\.git$//' \
    -e 's/^ssh:\/\///' \
    -e 's/^https:\/\/git@/https:\/\//')

  if [[ -n "$url" ]]; then
    open "$url"
    echo "🌐 Opened: $url"
  else
    echo "❌ Unable to detect remote URL"
    return 1
  fi
}

# Short aliases for common undo/reset operations
alias grs='git-reset-soft'
alias grm='git-reset-mixed'
alias grh='git-reset-hard'
alias gbh='git-back-head'
alias gbc='git-back-checkout'

# Open the current branch page on GitHub or GitLab
gh-open-branch() {
  typeset url branch
  url=$(git remote get-url origin 2>/dev/null | sed \
    -e 's/^git@/https:\/\//' \
    -e 's/com:/com\//' \
    -e 's/\.git$//' \
    -e 's/^ssh:\/\///' \
    -e 's/^https:\/\/git@/https:\/\//')
  branch=$(git rev-parse --abbrev-ref HEAD)

  if [[ -n "$url" && -n "$branch" ]]; then
    open "$url/tree/$branch"
    echo "🌿 Opened: $url/tree/$branch"
  else
    echo "❌ Failed to resolve URL or branch"
    return 1
  fi
}

# Open a specific commit on GitHub (supports tag, branch, or commit hash)
gh-open-commit() {
  typeset hash="${1:-HEAD}"
  typeset url commit

  url=$(git remote get-url origin 2>/dev/null | sed \
    -e 's/^git@/https:\/\//' \
    -e 's/com:/com\//' \
    -e 's/\.git$//' \
    -e 's/^ssh:\/\///' \
    -e 's/^https:\/\/git@/https:\/\//') || {
    echo "❌ No remote 'origin' found"
    return 1
  }

  if [[ "$url" != https://github.com/* ]]; then
    echo "❗ Only GitHub URLs are supported."
    return 1
  fi

  # Ensure annotated tag resolves to commit, not tag object
  commit=$(git rev-parse "${hash}^{commit}" 2>/dev/null) || {
    echo "❌ Invalid commit/tag/branch: $hash"
    return 1
  }

  typeset commit_url="$url/commit/$commit"
  echo "🔗 Opening: $commit_url"

  if command -v open &>/dev/null; then
    open "$commit_url"
  elif command -v xdg-open &>/dev/null; then
    xdg-open "$commit_url"
  else
    echo "❌ Cannot open URL (no open/xdg-open)"
    return 1
  fi
}

# Open default branch (main or master)
gh-open-default-branch() {
  typeset url default_branch
  url=$(git remote get-url origin 2>/dev/null | sed \
    -e 's/^git@/https:\/\//' \
    -e 's/com:/com\//' \
    -e 's/\.git$//' \
    -e 's/^ssh:\/\///' \
    -e 's/^https:\/\/git@/https:\/\//')

  default_branch=$(git remote show origin 2>/dev/null | awk '/HEAD branch/ {print $NF}')

  if [[ -n "$url" && -n "$default_branch" ]]; then
    open "$url/tree/$default_branch"
    echo "🌿 Opened: $url/tree/$default_branch"
  else
    echo "❌ Failed to resolve remote or default branch"
    return 1
  fi
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
#  3. Iterates through each staged file to include its HEAD version (before changes).
#     - For added files: marks them as new.
#     - For modified/deleted files: includes the original content from HEAD.
#  4. Formats all this into a Markdown document, including:
#     - 📄 Git staged diff (as `diff` block)
#     - 📂 Scope and directory tree (as `bash` block)
#     - 📚 Original file contents (as `ts` blocks per file)
#
# The result is piped to both:
#  - `pbcopy` for immediate pasting into ChatGPT or documentation tools.
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
  typeset tmpfile diff scope contents

  tmpfile="$(mktemp -t commit-context.md.XXXXXX)"
  diff="$(git diff --cached --no-color)"
  scope="$(git-scope staged | sed 's/\x1b\[[0-9;]*m//g')"

  if [[ -z "$diff" ]]; then
    printf "⚠️  No staged changes to record\n"
    return 1
  fi

  contents="$(
    git diff --cached --name-status | while IFS=$'\t' read -r fstatus file; do
      printf "### %s (%s)\n\n" "$file" "$fstatus"

      if [[ "$fstatus" == "A" ]]; then
        printf "[New file, no HEAD version]\n\n"
      elif [[ "$fstatus" == "M" || "$fstatus" == "D" ]]; then
        printf '```ts\n'
        git show HEAD:"$file" 2>/dev/null || printf '[HEAD version not found]\n'
        printf '```\n\n'
      else
        printf "[Unhandled status: %s]\n\n" "$fstatus"
      fi
    done
  )"

  printf "%s\n" "# Commit Context

Please help generate a clear and accurate commit message using the information below.

⚠️ Commit message must follow this format (used with commitlint):

- Use Semantic Commit format: \`type(scope): subject\`, all lowercase, in English.
- Enclose the message in a Markdown code block for easy copying.
- The subject (first line) must be under 100 characters.
- The body must detail the major changes, with each line under 100 characters.
- Each bullet point or sentence must start with a capital letter.

---

## 📂 Scope and file tree:

\`\`\`bash
$scope
\`\`\`

## 📄 Git staged diff:

\`\`\`diff
$diff
\`\`\`

## 📚 Original file contents (HEAD version):

$contents" | tee "$tmpfile" | pbcopy

  printf "✅ Commit context copied to clipboard with:\n"
  printf "  • Diff\n"
  printf "  • Scope summary (via git-scope staged)\n"
  printf "  • Original file contents (HEAD version)\n"
}

alias gcc='git-commit-context'
