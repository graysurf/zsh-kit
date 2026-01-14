# ────────────────────────────────────────────────────────
# Git remote open helpers
# ────────────────────────────────────────────────────────
if command -v safe_unalias >/dev/null; then
  safe_unalias \
    git-resolve-upstream \
    git-normalize-remote-url \
    git-open gho \
    gop gopl gob god goc gocs \
    gor goi goa got
fi

# git-resolve-upstream
# Resolve the upstream remote/branch backing the current HEAD.
# Usage: git-resolve-upstream
# Output:
# - Line 1: remote (default: origin)
# - Line 2: remote branch name
git-resolve-upstream() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset fallback_remote='origin' branch='' upstream='' remote='' remote_branch=''

  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || {
    print -u2 -r -- "❌ Unable to resolve current branch"
    return 1
  }

  upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)
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
# Usage: git-normalize-remote-url <remote>
# Output:
# - Prints the normalized URL to stdout.
git-normalize-remote-url() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset remote="$1"
  typeset raw_url='' normalized=''

  if [[ -z "$remote" ]]; then
    print -u2 -r -- "❌ git-normalize-remote-url requires remote name"
    return 1
  fi

  raw_url=$(git remote get-url "$remote" 2>/dev/null) || {
    print -u2 -r -- "❌ Failed to resolve remote URL for $remote"
    return 1
  }

  normalized=$(printf '%s\n' "$raw_url" | sed \
    -e 's/^git@/https:\/\//' \
    -e 's/com:/com\//' \
    -e 's/\.git$//' \
    -e 's/^ssh:\/\///' \
    -e 's/^https:\/\/git@/https:\/\//')

  if [[ -z "$normalized" ]]; then
    print -u2 -r -- "❌ Unable to normalize remote URL for $remote"
    return 1
  fi

  print -r -- "$normalized"
}

# _git_open_usage
# Print usage for `git-open`.
# Usage: _git_open_usage
_git_open_usage() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  print -r -- "Usage:"
  print -r -- "  git-open"
  print -r -- "  git-open repo [remote]"
  print -r -- "  git-open branch [ref]"
  print -r -- "  git-open default-branch [remote]"
  print -r -- "  git-open commit [ref]"
  print -r -- "  git-open compare [base] [head]"
  print -r -- "  git-open pr [number]"
  print -r -- "  git-open pulls [number]"
  print -r -- "  git-open issues [number]"
  print -r -- "  git-open actions [workflow]"
  print -r -- "  git-open releases [tag]"
  print -r -- "  git-open tags [tag]"
  print -r -- "  git-open commits [ref]"
  print -r -- "  git-open file <path> [ref]"
  print -r -- "  git-open blame <path> [ref]"
  print -r --
  print -r -- "Notes:"
  print -r -- "  - Uses the upstream remote if configured; falls back to origin."
  print -r -- "  - Collaboration pages prefer GIT_OPEN_COLLAB_REMOTE when set (pr/pulls/issues/actions/releases/tags)."
  print -r -- "  - pr uses gh when available; otherwise falls back to the compare page."
  print -r -- "  - tags <tag> opens the release page for the given tag."
  print -r -- "  - Singular aliases: issue, action, release, tag."
}

# _git_open_provider <base_url>
# Detect Git hosting provider from a base URL.
# Usage: _git_open_provider <base_url>
_git_open_provider() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset base_url="${1-}"
  typeset host='' provider=''

  if [[ -z "$base_url" ]]; then
    print -u2 -r -- "❌ Missing base URL"
    return 1
  fi

  host="${base_url#*://}"
  host="${host%%/*}"

  case "$host" in
    github.com) provider='github' ;;
    gitlab.com) provider='gitlab' ;;
    *)
      if [[ "$host" == *gitlab* ]]; then
        provider='gitlab'
      elif [[ "$host" == *github* ]]; then
        provider='github'
      else
        provider='generic'
      fi
      ;;
  esac

  print -r -- "$provider"
}

# _git_open_github_repo_slug <base_url>
# Extract "<owner>/<repo>" from a normalized GitHub base URL.
# Usage: _git_open_github_repo_slug <base_url>
_git_open_github_repo_slug() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset base_url="${1-}"
  typeset path='' owner='' rest='' repo=''

  if [[ -z "$base_url" ]]; then
    print -u2 -r -- "❌ Missing base URL"
    return 1
  fi

  path="${base_url#*://}"
  path="${path#*/}"

  owner="${path%%/*}"
  rest="${path#*/}"

  if [[ -z "$owner" || -z "$rest" || "$rest" == "$path" ]]; then
    print -u2 -r -- "❌ Invalid GitHub base URL: $base_url"
    return 1
  fi

  repo="${rest%%/*}"
  if [[ -z "$repo" ]]; then
    print -u2 -r -- "❌ Invalid GitHub base URL: $base_url"
    return 1
  fi

  print -r -- "${owner}/${repo}"
}

# _git_open_open_url <url> [label]
# Open URL using `open` (macOS) or `xdg-open`, then print a one-line message.
# Usage: _git_open_open_url <url> [label]
_git_open_open_url() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset url="${1-}"
  typeset label="${2-Opened}"

  if [[ -z "$url" ]]; then
    print -u2 -r -- "❌ Missing URL"
    return 1
  fi

  if command -v open &>/dev/null; then
    open "$url" || return $?
  elif command -v xdg-open &>/dev/null; then
    xdg-open "$url" || return $?
  else
    print -u2 -r -- "❌ Cannot open URL (no open/xdg-open)"
    return 1
  fi

  print -r -- "${label}: $url"
}

# _git_open_urlencode_path <path>
# Percent-encode a repo-relative path while preserving '/' separators.
# Usage: _git_open_urlencode_path <path>
_git_open_urlencode_path() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset path="${1-}"

  if [[ -z "$path" ]]; then
    print -u2 -r -- "❌ Missing path"
    return 1
  fi

  if command -v python3 &>/dev/null; then
    python3 - "$path" <<'PY'
import sys
from urllib.parse import quote
print(quote(sys.argv[1], safe="/"))
PY
    return $?
  fi

  print -r -- "${path// /%20}"
}

# _git_open_urlencode_query_value <value>
# Percent-encode a query parameter value.
# Usage: _git_open_urlencode_query_value <value>
_git_open_urlencode_query_value() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset value="${1-}"

  if command -v python3 &>/dev/null; then
    python3 - "$value" <<'PY'
import sys
from urllib.parse import quote
print(quote(sys.argv[1], safe=""))
PY
    return $?
  fi

  print -r -- "${value// /%20}"
}

# _git_open_default_branch_name <remote>
# Resolve and print the default branch name for a remote.
# Usage: _git_open_default_branch_name <remote>
_git_open_default_branch_name() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset remote="${1-}"
  typeset default_branch=''

  if [[ -z "$remote" ]]; then
    print -u2 -r -- "❌ Missing remote"
    return 1
  fi

  default_branch=$(git remote show "$remote" 2>/dev/null | awk '/HEAD branch/ {print $NF}' || true)
  if [[ -z "$default_branch" ]]; then
    print -u2 -r -- "❌ Failed to resolve default branch for $remote"
    return 1
  fi

  print -r -- "$default_branch"
}

# _git_open_tree_url <provider> <base_url> <ref>
# Build a branch/tree URL for a given provider.
# Usage: _git_open_tree_url <provider> <base_url> <ref>
_git_open_tree_url() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset provider="${1-}"
  typeset base_url="${2-}"
  typeset ref="${3-}"

  if [[ -z "$base_url" || -z "$ref" ]]; then
    print -u2 -r -- "❌ Missing base_url/ref"
    return 1
  fi

  case "$provider" in
    gitlab) print -r -- "$base_url/-/tree/$ref" ;;
    *)      print -r -- "$base_url/tree/$ref" ;;
  esac
}

# _git_open_commit_url <provider> <base_url> <commit>
# Build a commit URL for a given provider.
# Usage: _git_open_commit_url <provider> <base_url> <commit>
_git_open_commit_url() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset provider="${1-}"
  typeset base_url="${2-}"
  typeset commit="${3-}"

  if [[ -z "$base_url" || -z "$commit" ]]; then
    print -u2 -r -- "❌ Missing base_url/commit"
    return 1
  fi

  case "$provider" in
    gitlab) print -r -- "$base_url/-/commit/$commit" ;;
    *)      print -r -- "$base_url/commit/$commit" ;;
  esac
}

# _git_open_compare_url <provider> <base_url> <base> <head>
# Build a compare URL for a given provider.
# Usage: _git_open_compare_url <provider> <base_url> <base> <head>
_git_open_compare_url() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset provider="${1-}"
  typeset base_url="${2-}"
  typeset base="${3-}"
  typeset head="${4-}"

  if [[ -z "$base_url" || -z "$base" || -z "$head" ]]; then
    print -u2 -r -- "❌ Missing compare base/head"
    return 1
  fi

  case "$provider" in
    gitlab) print -r -- "$base_url/-/compare/${base}...${head}" ;;
    *)      print -r -- "$base_url/compare/${base}...${head}" ;;
  esac
}

# _git_open_blob_url <provider> <base_url> <ref> <path>
# Build a file (blob) URL for a given provider.
# Usage: _git_open_blob_url <provider> <base_url> <ref> <path>
_git_open_blob_url() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset provider="${1-}"
  typeset base_url="${2-}"
  typeset ref="${3-}"
  typeset path="${4-}"
  typeset encoded_path=''

  if [[ -z "$base_url" || -z "$ref" || -z "$path" ]]; then
    print -u2 -r -- "❌ Missing blob ref/path"
    return 1
  fi

  encoded_path=$(_git_open_urlencode_path "$path") || return 1

  case "$provider" in
    gitlab) print -r -- "$base_url/-/blob/$ref/$encoded_path" ;;
    *)      print -r -- "$base_url/blob/$ref/$encoded_path" ;;
  esac
}

# _git_open_blame_url <provider> <base_url> <ref> <path>
# Build a blame URL for a given provider.
# Usage: _git_open_blame_url <provider> <base_url> <ref> <path>
_git_open_blame_url() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset provider="${1-}"
  typeset base_url="${2-}"
  typeset ref="${3-}"
  typeset path="${4-}"
  typeset encoded_path=''

  if [[ -z "$base_url" || -z "$ref" || -z "$path" ]]; then
    print -u2 -r -- "❌ Missing blame ref/path"
    return 1
  fi

  encoded_path=$(_git_open_urlencode_path "$path") || return 1

  case "$provider" in
    gitlab) print -r -- "$base_url/-/blame/$ref/$encoded_path" ;;
    *)      print -r -- "$base_url/blame/$ref/$encoded_path" ;;
  esac
}

# _git_open_commits_url <provider> <base_url> <ref>
# Build a commits list URL for a given provider.
# Usage: _git_open_commits_url <provider> <base_url> <ref>
_git_open_commits_url() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset provider="${1-}"
  typeset base_url="${2-}"
  typeset ref="${3-}"

  if [[ -z "$base_url" || -z "$ref" ]]; then
    print -u2 -r -- "❌ Missing commits ref"
    return 1
  fi

  case "$provider" in
    gitlab) print -r -- "$base_url/-/commits/$ref" ;;
    *)      print -r -- "$base_url/commits/$ref" ;;
  esac
}

# _git_open_release_tag_url <provider> <base_url> <tag>
# Build a release page URL for a tag (provider-dependent).
# Usage: _git_open_release_tag_url <provider> <base_url> <tag>
_git_open_release_tag_url() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset provider="${1-}"
  typeset base_url="${2-}"
  typeset tag="${3-}"
  typeset encoded_tag=''

  if [[ -z "$base_url" || -z "$tag" ]]; then
    print -u2 -r -- "❌ Missing release tag URL inputs"
    return 1
  fi

  encoded_tag=$(_git_open_urlencode_query_value "$tag") || return 1

  case "$provider" in
    gitlab) print -r -- "$base_url/-/releases/$encoded_tag" ;;
    *)      print -r -- "$base_url/releases/tag/$encoded_tag" ;;
  esac
}

# _git_open_context
# Resolve base URL + remote + branch for the current repo.
# Usage: _git_open_context
# Output:
# - Line 1: base URL
# - Line 2: remote
# - Line 3: remote branch name
# - Line 4: provider (github|gitlab|generic)
_git_open_context() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset -a upstream=()
  typeset remote='' remote_branch='' base_url=''
  typeset provider=''

  upstream=(${(@f)$(git-resolve-upstream)}) || return 1
  if (( ${#upstream[@]} < 2 )); then
    print -u2 -r -- "❌ Failed to resolve upstream information"
    return 1
  fi

  remote="${upstream[1]}"
  remote_branch="${upstream[2]}"

  base_url=$(git-normalize-remote-url "$remote") || return 1
  provider=$(_git_open_provider "$base_url") || return 1

  print -r -- "$base_url"
  print -r -- "$remote"
  print -r -- "$remote_branch"
  print -r -- "$provider"
}

# _git_open_remote_context <remote>
# Resolve base URL + provider for a specific remote name.
# Usage: _git_open_remote_context <remote>
# Output:
# - Line 1: base URL
# - Line 2: provider (github|gitlab|generic)
_git_open_remote_context() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset remote="${1-}"
  typeset base_url='' provider=''

  if [[ -z "$remote" ]]; then
    print -u2 -r -- "❌ Missing remote name"
    return 1
  fi

  base_url=$(git-normalize-remote-url "$remote") || return 1
  provider=$(_git_open_provider "$base_url") || return 1

  print -r -- "$base_url"
  print -r -- "$provider"
}

# _git_open_collab_context
# Resolve base URL + remote + provider for collaboration/list pages.
# Uses `GIT_OPEN_COLLAB_REMOTE` when set (and exists); otherwise falls back to `_git_open_context`.
# Usage: _git_open_collab_context
# Output:
# - Line 1: base URL
# - Line 2: remote
# - Line 3: provider (github|gitlab|generic)
_git_open_collab_context() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset collab_remote="${GIT_OPEN_COLLAB_REMOTE-}"
  typeset base_url='' provider=''

  if [[ -n "$collab_remote" ]]; then
    base_url="$(git-normalize-remote-url "$collab_remote" 2>/dev/null || true)"
    if [[ -n "$base_url" ]]; then
      provider=$(_git_open_provider "$base_url") || return 1
      print -r -- "$base_url"
      print -r -- "$collab_remote"
      print -r -- "$provider"
      return 0
    fi
  fi

  typeset -a ctx=()
  ctx=(${(@f)$(_git_open_context)}) || return 1
  base_url="${ctx[1]}"
  collab_remote="${ctx[2]}"
  provider="${ctx[4]}"

  print -r -- "$base_url"
  print -r -- "$collab_remote"
  print -r -- "$provider"
}

# _git_open_repo [remote]
# Open the repository homepage for the current repo (or a named remote).
# Usage: _git_open_repo [remote]
_git_open_repo() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  if (( $# > 1 )); then
    print -u2 -r -- "❌ git-open repo takes at most one remote name"
    _git_open_usage
    return 2
  fi

  typeset base_url=''

  if (( $# == 1 )); then
    case "$1" in
      -h|--help|help)
        _git_open_usage
        return 0
        ;;
    esac

    base_url=$(git-normalize-remote-url "$1") || return 1
  else
    typeset -a ctx=()
    ctx=(${(@f)$(_git_open_context)}) || return 1
    base_url="${ctx[1]}"
  fi

  _git_open_open_url "$base_url" "🌐 Opened"
}

# _git_open_branch [ref]
# Open the tree page for a branch/tag/ref (default: upstream branch).
# Usage: _git_open_branch [ref]
_git_open_branch() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  if (( $# > 1 )); then
    print -u2 -r -- "❌ git-open branch takes at most one ref"
    _git_open_usage
    return 2
  fi

  if (( $# == 1 )); then
    case "$1" in
      -h|--help|help)
        _git_open_usage
        return 0
        ;;
    esac
  fi

  typeset -a ctx=()
  typeset base_url='' remote_branch='' provider='' ref='' target_url=''

  ctx=(${(@f)$(_git_open_context)}) || return 1
  base_url="${ctx[1]}"
  remote_branch="${ctx[3]}"
  provider="${ctx[4]}"

  ref="${1:-$remote_branch}"
  target_url=$(_git_open_tree_url "$provider" "$base_url" "$ref") || return 1
  _git_open_open_url "$target_url" "🌿 Opened"
}

# _git_open_commit [ref]
# Open the commit page for a ref (default: HEAD).
# Usage: _git_open_commit [ref]
_git_open_commit() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  if (( $# > 1 )); then
    print -u2 -r -- "❌ git-open commit takes at most one ref"
    _git_open_usage
    return 2
  fi

  typeset ref="${1:-HEAD}"
  typeset -a ctx=()
  typeset base_url='' provider='' commit='' commit_url=''

  ctx=(${(@f)$(_git_open_context)}) || return 1
  base_url="${ctx[1]}"
  provider="${ctx[4]}"

  commit=$(git rev-parse "${ref}^{commit}" 2>/dev/null) || {
    print -u2 -r -- "❌ Invalid commit/tag/branch: $ref"
    return 1
  }

  commit_url=$(_git_open_commit_url "$provider" "$base_url" "$commit") || return 1
  _git_open_open_url "$commit_url" "🔗 Opened"
}

# _git_open_default_branch [remote]
# Open the default branch tree page (default: upstream remote).
# Usage: _git_open_default_branch [remote]
_git_open_default_branch() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  if (( $# > 1 )); then
    print -u2 -r -- "❌ git-open default-branch takes at most one remote name"
    _git_open_usage
    return 2
  fi

  typeset base_url='' remote='' provider='' default_branch='' target_url=''

  if (( $# == 1 )); then
    case "$1" in
      -h|--help|help)
        _git_open_usage
        return 0
        ;;
    esac

    remote="$1"

    typeset -a remote_ctx=()
    remote_ctx=(${(@f)$(_git_open_remote_context "$remote")}) || return 1
    base_url="${remote_ctx[1]}"
    provider="${remote_ctx[2]}"
  else
    typeset -a ctx=()
    ctx=(${(@f)$(_git_open_context)}) || return 1
    base_url="${ctx[1]}"
    remote="${ctx[2]}"
    provider="${ctx[4]}"
  fi

  default_branch=$(_git_open_default_branch_name "$remote") || return 1
  target_url=$(_git_open_tree_url "$provider" "$base_url" "$default_branch") || return 1
  _git_open_open_url "$target_url" "🌿 Opened"
}

# _git_open_compare [base] [head]
# Open the compare page (default: <default-branch>...<current-branch>).
# Usage: _git_open_compare [base] [head]
_git_open_compare() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  if (( $# > 2 )); then
    print -u2 -r -- "❌ git-open compare takes at most two refs"
    _git_open_usage
    return 2
  fi

  typeset -a ctx=()
  typeset base_url='' remote='' remote_branch='' provider=''
  typeset base='' head='' target_url=''

  ctx=(${(@f)$(_git_open_context)}) || return 1
  base_url="${ctx[1]}"
  remote="${ctx[2]}"
  remote_branch="${ctx[3]}"
  provider="${ctx[4]}"

  case $# in
    0)
      base=$(_git_open_default_branch_name "$remote") || return 1
      head="$remote_branch"
      ;;
    1)
      base="${1}"
      head="$remote_branch"
      ;;
    2)
      base="${1}"
      head="${2}"
      ;;
  esac

  target_url=$(_git_open_compare_url "$provider" "$base_url" "$base" "$head") || return 1
  _git_open_open_url "$target_url" "🔀 Opened"
}

# _git_open_pr [number]
# Open PR/MR page (or the current-branch compare/new PR page when number is omitted).
# Usage: _git_open_pr [number]
# Notes:
# - GitHub: prefers `gh pr view --web` when available.
_git_open_pr() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  if (( $# > 1 )); then
    print -u2 -r -- "❌ git-open pr takes at most one number"
    _git_open_usage
    return 2
  fi

  typeset -a ctx=() collab_ctx=()
  typeset base_url='' remote='' remote_branch='' provider=''
  typeset collab_base_url='' collab_remote='' collab_provider=''
  typeset base='' target_url='' source_enc='' target_enc='' pr_id=''

  ctx=(${(@f)$(_git_open_context)}) || return 1
  base_url="${ctx[1]}"
  remote="${ctx[2]}"
  remote_branch="${ctx[3]}"
  provider="${ctx[4]}"

  collab_ctx=(${(@f)$(_git_open_collab_context)}) || return 1
  collab_base_url="${collab_ctx[1]}"
  collab_remote="${collab_ctx[2]}"
  collab_provider="${collab_ctx[3]}"

  if (( $# == 1 )); then
    case "$1" in
      -h|--help|help)
        _git_open_usage
        return 0
        ;;
    esac

    pr_id="${1#\#}"
    if [[ "$pr_id" != <-> ]]; then
      print -u2 -r -- "❌ Invalid PR number: $1"
      return 2
    fi

    case "$collab_provider" in
      github) target_url="$collab_base_url/pull/$pr_id" ;;
      gitlab) target_url="$collab_base_url/-/merge_requests/$pr_id" ;;
      *)
        print -u2 -r -- "❗ pr <number> is only supported for GitHub/GitLab remotes."
        return 1
        ;;
    esac

    _git_open_open_url "$target_url" "🧷 Opened"
    return 0
  fi

  case "$collab_provider" in
    github)
      if command -v gh &>/dev/null; then
        typeset collab_slug=''
        if [[ "$collab_base_url" == *'github.com/'* ]]; then
          collab_slug="$(_git_open_github_repo_slug "$collab_base_url" 2>/dev/null || true)"
        fi
        if [[ -n "$collab_slug" ]]; then
          if gh pr view --web --repo "$collab_slug" >/dev/null 2>&1; then
            print -r -- "🧷 Opened PR via gh"
            return 0
          fi
        fi

        if [[ -z "$collab_slug" || "$collab_base_url" != "$base_url" ]]; then
          if gh pr view --web >/dev/null 2>&1; then
            print -r -- "🧷 Opened PR via gh"
            return 0
          fi
        fi
      fi

      base=$(_git_open_default_branch_name "$collab_remote") || return 1

      typeset head_ref="$remote_branch"
      if [[ "$collab_base_url" != "$base_url" && "$collab_base_url" == *'github.com/'* && "$base_url" == *'github.com/'* ]]; then
        typeset upstream_slug='' upstream_owner=''
        upstream_slug="$(_git_open_github_repo_slug "$base_url" 2>/dev/null || true)"
        upstream_owner="${upstream_slug%%/*}"
        if [[ -n "$upstream_owner" ]]; then
          head_ref="${upstream_owner}:${remote_branch}"
        fi
      fi

      target_url="$collab_base_url/compare/${base}...${head_ref}?expand=1"
      _git_open_open_url "$target_url" "🧷 Opened"
      ;;
    gitlab)
      base=$(_git_open_default_branch_name "$collab_remote") || return 1
      source_enc=$(_git_open_urlencode_query_value "$remote_branch") || return 1
      target_enc=$(_git_open_urlencode_query_value "$base") || return 1
      target_url="$collab_base_url/-/merge_requests/new?merge_request[source_branch]=$source_enc&merge_request[target_branch]=$target_enc"
      _git_open_open_url "$target_url" "🧷 Opened"
      ;;
    *)
      base=$(_git_open_default_branch_name "$collab_remote") || return 1
      target_url="$collab_base_url/compare/${base}...${remote_branch}"
      _git_open_open_url "$target_url" "🧷 Opened"
      ;;
  esac
}

# _git_open_pulls [number]
# Open PR/MR list (or a specific PR/MR when a number is provided).
# Usage: _git_open_pulls [number]
_git_open_pulls() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  if (( $# > 1 )); then
    print -u2 -r -- "❌ git-open pulls takes at most one number"
    _git_open_usage
    return 2
  fi

  if (( $# == 1 )); then
    _git_open_pr "$1"
    return $?
  fi

  typeset -a ctx=()
  typeset base_url='' provider='' target_url=''

  ctx=(${(@f)$(_git_open_collab_context)}) || return 1
  base_url="${ctx[1]}"
  provider="${ctx[3]}"

  case "$provider" in
    gitlab) target_url="$base_url/-/merge_requests" ;;
    *)      target_url="$base_url/pulls" ;;
  esac

  _git_open_open_url "$target_url" "📌 Opened"
}

# _git_open_issues [number]
# Open issues list (or a specific issue when a number is provided).
# Usage: _git_open_issues [number]
_git_open_issues() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  if (( $# > 1 )); then
    print -u2 -r -- "❌ git-open issues takes at most one number"
    _git_open_usage
    return 2
  fi

  typeset base_url='' provider='' target_url=''

  typeset -a ctx=()
  ctx=(${(@f)$(_git_open_collab_context)}) || return 1
  base_url="${ctx[1]}"
  provider="${ctx[3]}"

  if (( $# == 1 )); then
    typeset issue_id="${1#\#}"
    if [[ "$issue_id" != <-> ]]; then
      print -u2 -r -- "❌ Invalid issue number: $1"
      return 2
    fi

    case "$provider" in
      gitlab) target_url="$base_url/-/issues/$issue_id" ;;
      *)      target_url="$base_url/issues/$issue_id" ;;
    esac
  else
    case "$provider" in
      gitlab) target_url="$base_url/-/issues" ;;
      *)      target_url="$base_url/issues" ;;
    esac
  fi

  _git_open_open_url "$target_url" "📌 Opened"
}

# _git_open_actions [workflow]
# Open GitHub Actions (optionally for a workflow or query).
# Usage: _git_open_actions [workflow]
# Notes:
# - GitHub only.
_git_open_actions() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  if (( $# > 1 )); then
    print -u2 -r -- "❌ git-open actions takes at most one workflow"
    _git_open_usage
    return 2
  fi

  typeset -a ctx=()
  typeset base_url='' provider='' target_url=''

  ctx=(${(@f)$(_git_open_collab_context)}) || return 1
  base_url="${ctx[1]}"
  provider="${ctx[3]}"

  if [[ "$provider" != "github" ]]; then
    print -u2 -r -- "❗ actions is only supported for GitHub remotes."
    return 1
  fi

  if (( $# == 1 )); then
    typeset workflow="$1"
    case "$workflow" in
      -h|--help|help)
        _git_open_usage
        return 0
        ;;
    esac

    if [[ "$workflow" == *.yml || "$workflow" == *.yaml ]]; then
      typeset encoded_workflow=''
      encoded_workflow=$(_git_open_urlencode_query_value "$workflow") || return 1
      target_url="$base_url/actions/workflows/$encoded_workflow"
    else
      typeset q='' encoded_q=''
      q="workflow:$workflow"
      encoded_q=$(_git_open_urlencode_query_value "$q") || return 1
      target_url="$base_url/actions?query=$encoded_q"
    fi
  else
    target_url="$base_url/actions"
  fi

  _git_open_open_url "$target_url" "📌 Opened"
}

# _git_open_releases [tag]
# Open releases list (or the release page for a tag).
# Usage: _git_open_releases [tag]
_git_open_releases() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  if (( $# > 1 )); then
    print -u2 -r -- "❌ git-open releases takes at most one tag"
    _git_open_usage
    return 2
  fi

  typeset -a ctx=()
  typeset base_url='' provider='' target_url=''

  ctx=(${(@f)$(_git_open_collab_context)}) || return 1
  base_url="${ctx[1]}"
  provider="${ctx[3]}"

  if (( $# == 1 )); then
    case "$1" in
      -h|--help|help)
        _git_open_usage
        return 0
        ;;
    esac

    target_url=$(_git_open_release_tag_url "$provider" "$base_url" "$1") || return 1
  else
    case "$provider" in
      gitlab) target_url="$base_url/-/releases" ;;
      *)      target_url="$base_url/releases" ;;
    esac
  fi

  _git_open_open_url "$target_url" "📌 Opened"
}

# _git_open_tags [tag]
# Open tags list (or the release page for a tag).
# Usage: _git_open_tags [tag]
# Notes:
# - Tag tree uses `git-open branch <tag>`.
_git_open_tags() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  if (( $# > 1 )); then
    print -u2 -r -- "❌ git-open tags takes at most one tag"
    _git_open_usage
    return 2
  fi

  typeset -a ctx=()
  typeset base_url='' provider='' target_url=''

  ctx=(${(@f)$(_git_open_collab_context)}) || return 1
  base_url="${ctx[1]}"
  provider="${ctx[3]}"

  if (( $# == 1 )); then
    case "$1" in
      -h|--help|help)
        _git_open_usage
        return 0
        ;;
    esac

    target_url=$(_git_open_release_tag_url "$provider" "$base_url" "$1") || return 1
  else
    case "$provider" in
      gitlab) target_url="$base_url/-/tags" ;;
      *)      target_url="$base_url/tags" ;;
    esac
  fi

  _git_open_open_url "$target_url" "📌 Opened"
}

# _git_open_commits [ref]
# Open commit history page for a ref (default: upstream branch).
# Usage: _git_open_commits [ref]
_git_open_commits() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  if (( $# > 1 )); then
    print -u2 -r -- "❌ git-open commits takes at most one ref"
    _git_open_usage
    return 2
  fi

  typeset -a ctx=()
  typeset base_url='' remote_branch='' provider='' ref='' target_url=''

  ctx=(${(@f)$(_git_open_context)}) || return 1
  base_url="${ctx[1]}"
  remote_branch="${ctx[3]}"
  provider="${ctx[4]}"

  ref="${1:-$remote_branch}"
  target_url=$(_git_open_commits_url "$provider" "$base_url" "$ref") || return 1
  _git_open_open_url "$target_url" "📜 Opened"
}

# _git_open_file <path> [ref]
# Open file view at a ref (default: upstream branch).
# Usage: _git_open_file <path> [ref]
_git_open_file() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  if (( $# < 1 || $# > 2 )); then
    print -u2 -r -- "❌ Usage: git-open file <path> [ref]"
    return 2
  fi

  typeset path="${1-}"
  typeset ref="${2-}"
  typeset -a ctx=()
  typeset base_url='' remote_branch='' provider='' target_url=''

  path="${path#./}"
  path="${path#/}"

  ctx=(${(@f)$(_git_open_context)}) || return 1
  base_url="${ctx[1]}"
  remote_branch="${ctx[3]}"
  provider="${ctx[4]}"

  if [[ -z "$ref" ]]; then
    ref="$remote_branch"
  fi

  target_url=$(_git_open_blob_url "$provider" "$base_url" "$ref" "$path") || return 1
  _git_open_open_url "$target_url" "📄 Opened"
}

# _git_open_blame <path> [ref]
# Open blame view for a file at a ref (default: upstream branch).
# Usage: _git_open_blame <path> [ref]
_git_open_blame() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  if (( $# < 1 || $# > 2 )); then
    print -u2 -r -- "❌ Usage: git-open blame <path> [ref]"
    return 2
  fi

  typeset path="${1-}"
  typeset ref="${2-}"
  typeset -a ctx=()
  typeset base_url='' remote_branch='' provider='' target_url=''

  path="${path#./}"
  path="${path#/}"

  ctx=(${(@f)$(_git_open_context)}) || return 1
  base_url="${ctx[1]}"
  remote_branch="${ctx[3]}"
  provider="${ctx[4]}"

  if [[ -z "$ref" ]]; then
    ref="$remote_branch"
  fi

  target_url=$(_git_open_blame_url "$provider" "$base_url" "$ref" "$path") || return 1
  _git_open_open_url "$target_url" "🕵️ Opened"
}

# git-open [command] [args...]
# Open a repository/branch/commit page for the current repo in your browser.
# Usage: git-open
#        git-open repo [remote]
#        git-open branch [ref]
#        git-open default-branch [remote]
#        git-open commit [ref]
#        git-open compare [base] [head]
#        git-open pr [number]
#        git-open pulls [number]
#        git-open issues [number]
#        git-open actions [workflow]
#        git-open releases [tag]
#        git-open tags [tag]
#        git-open commits [ref]
#        git-open file <path> [ref]
#        git-open blame <path> [ref]
# Notes:
# - Uses the upstream remote if configured; falls back to origin.
# - pr uses gh when available; otherwise falls back to the compare page.
git-open() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset cmd="${1-}"

  case "$cmd" in
    ''|repo)
      [[ -n "$cmd" ]] && shift
      _git_open_repo "$@"
      ;;
    branch)
      shift
      _git_open_branch "$@"
      ;;
    default|default-branch)
      shift
      _git_open_default_branch "$@"
      ;;
    commit)
      shift
      _git_open_commit "$@"
      ;;
    compare)
      shift
      _git_open_compare "$@"
      ;;
    pr|pull-request|mr|merge-request)
      shift
      _git_open_pr "$@"
      ;;
    pulls|prs|merge-requests|mrs)
      shift
      _git_open_pulls "$@"
      ;;
    issue|issues)
      shift
      _git_open_issues "$@"
      ;;
    action|actions)
      shift
      _git_open_actions "$@"
      ;;
    release|releases)
      shift
      _git_open_releases "$@"
      ;;
    tag|tags)
      shift
      _git_open_tags "$@"
      ;;
    commits|history)
      shift
      _git_open_commits "$@"
      ;;
    file|blob)
      shift
      _git_open_file "$@"
      ;;
    blame)
      shift
      _git_open_blame "$@"
      ;;
    -h|--help|help)
      _git_open_usage
      ;;
    *)
      print -u2 -r -- "❌ Unknown git-open command: $cmd"
      _git_open_usage
      return 2
      ;;
  esac
}

# gho
# Alias of `git-open`.
# Usage: gho [command] [args...]
alias gho='git-open'

# gop [number]
# Alias of `git-open pr`.
# Usage: gop [number]
alias gop='git-open pr'

# gob [ref]
# Alias of `git-open branch`.
# Usage: gob [ref]
alias gob='git-open branch'

# god [remote]
# Alias of `git-open default-branch`.
# Usage: god [remote]
alias god='git-open default-branch'

# goc [ref]
# Alias of `git-open commit`.
# Usage: goc [ref]
alias goc='git-open commit'

# gocs [ref]
# Alias of `git-open commits`.
# Usage: gocs [ref]
alias gocs='git-open commits'

# gopl [number]
# Alias of `git-open pulls`.
# Usage: gopl [number]
alias gopl='git-open pulls'

# gor [remote]
# Alias of `git-open repo`.
# Usage: gor [remote]
alias gor='git-open repo'

# goi [number]
# Alias of `git-open issues`.
# Usage: goi [number]
alias goi='git-open issues'

# goa [workflow]
# Alias of `git-open actions`.
# Usage: goa [workflow]
alias goa='git-open actions'

# got [tag]
# Alias of `git-open tags`.
# Usage: got [tag]
alias got='git-open tags'
