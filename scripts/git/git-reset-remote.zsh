git-reset-remote() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  zmodload zsh/zutil 2>/dev/null || {
    print -u2 -r -- "❌ zsh/zutil is required for zparseopts."
    return 1
  }

  typeset -A opts=()
  zparseopts -D -E -A opts -- \
    h -help \
    y -yes \
    r: -remote: \
    b: -branch: \
    -ref: \
    -no-fetch \
    -prune \
    -clean \
    -set-upstream || return 2

  if (( ${+opts[-h]} || ${+opts[--help]} )); then
    print -r -- "git-reset-remote: overwrite current local branch with a remote-tracking branch (DANGEROUS)"
    print -r --
    print -r -- "Usage:"
    print -r -- "  git-reset-remote  # reset current branch to its upstream (or origin/<branch>)"
    print -r -- "  git-reset-remote --ref origin/main"
    print -r -- "  git-reset-remote -r origin -b main"
    print -r --
    print -r -- "Options:"
    print -r -- "  -r, --remote <name>        Remote name (default: from upstream, else origin)"
    print -r -- "  -b, --branch <name>        Remote branch name (default: from upstream, else current branch)"
    print -r -- "      --ref <remote/branch>  Shortcut for --remote/--branch"
    print -r -- "      --no-fetch             Skip 'git fetch' (uses existing remote-tracking refs)"
    print -r -- "      --prune                Use 'git fetch --prune'"
    print -r -- "      --set-upstream         Set upstream of current branch to <remote>/<branch>"
    print -r -- "      --clean                After reset, optionally run 'git clean -fd' (removes untracked)"
    print -r -- "  -y, --yes                  Skip confirmations"
    return 0
  fi

  git rev-parse --git-dir >/dev/null 2>&1 || {
    print -u2 -r -- "❌ Not inside a Git repository."
    return 1
  }

  typeset current_branch=''
  current_branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null)" || {
    print -u2 -r -- "❌ Detached HEAD. Switch to a branch first."
    return 1
  }

  typeset upstream='' remote='' remote_branch='' ref=''
  upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"

  if [[ -n "${opts[--ref]-}" ]]; then
    ref="${opts[--ref]}"
    if [[ "$ref" != */* ]]; then
      print -u2 -r -- "❌ --ref must look like '<remote>/<branch>' (got: $ref)"
      return 2
    fi
    remote="${ref%%/*}"
    remote_branch="${ref#*/}"
  else
    remote="${opts[-r]-}"
    [[ -n "${opts[--remote]-}" ]] && remote="${opts[--remote]}"

    remote_branch="${opts[-b]-}"
    [[ -n "${opts[--branch]-}" ]] && remote_branch="${opts[--branch]}"

    if [[ -z "$remote" && -n "$upstream" && "$upstream" == */* ]]; then
      remote="${upstream%%/*}"
    fi
    [[ -z "$remote" ]] && remote='origin'

    if [[ -z "$remote_branch" ]]; then
      if [[ -n "$upstream" && "$upstream" == */* && "${upstream#*/}" != 'HEAD' ]]; then
        remote_branch="${upstream#*/}"
      else
        remote_branch="$current_branch"
      fi
    fi
  fi

  typeset target_ref="$remote/$remote_branch"
  typeset want_yes=0 want_clean=0 want_prune=0 want_fetch=1 want_set_upstream=0
  (( ${+opts[-y]} || ${+opts[--yes]} )) && want_yes=1
  (( ${+opts[--clean]} )) && want_clean=1
  (( ${+opts[--prune]} )) && want_prune=1
  (( ${+opts[--no-fetch]} )) && want_fetch=0
  (( ${+opts[--set-upstream]} )) && want_set_upstream=1

  if (( want_fetch )); then
    if (( want_prune )); then
      git fetch --prune -- "$remote" || return $?
    else
      git fetch -- "$remote" || return $?
    fi
  fi

  if ! git show-ref --verify --quiet "refs/remotes/$remote/$remote_branch"; then
    print -u2 -r -- "❌ Remote-tracking branch not found: $target_ref"
    print -u2 -r -- "   Try: git fetch --prune -- $remote"
    print -u2 -r -- "   Or verify: git branch -r | rg -n -- \"^\\s*$remote/$remote_branch$\""
    return 1
  fi

  typeset status_porcelain=''
  status_porcelain="$(git status --porcelain 2>/dev/null || true)"

  if (( !want_yes )); then
    print -r -- "⚠️  This will OVERWRITE local branch '$current_branch' with '$target_ref'."
    if [[ -n "$status_porcelain" ]]; then
      print -r -- "🔥 Tracked staged/unstaged changes will be DISCARDED by --hard."
      print -r -- "🧹 Untracked files will be kept (use --clean to remove)."
    fi
    print -n -- "❓ Proceed with: git reset --hard $target_ref ? [y/N] "
    typeset confirm=''
    read -r confirm
    if [[ "$confirm" != [yY] ]]; then
      print -r -- "🚫 Aborted"
      return 1
    fi
  fi

  git reset --hard "$target_ref" || return $?

  if (( want_clean )); then
    if (( !want_yes )); then
      print -r -- "⚠️  Next: git clean -fd (removes untracked files/dirs)"
      print -n -- "❓ Proceed with: git clean -fd ? [y/N] "
      typeset confirm_clean=''
      read -r confirm_clean
      if [[ "$confirm_clean" != [yY] ]]; then
        print -r -- "ℹ️  Skipped git clean -fd"
        want_clean=0
      fi
    fi
    if (( want_clean )); then
      git clean -fd || return $?
    fi
  fi

  if (( want_set_upstream || ${#upstream} == 0 )); then
    git branch --set-upstream-to="$target_ref" "$current_branch" >/dev/null 2>&1 || true
  fi

  print -r -- "✅ Done. '$current_branch' now matches '$target_ref'."
  return 0
}
