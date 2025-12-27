# ────────────────────────────────────────────────────────
# Aliases and Unalias
# ────────────────────────────────────────────────────────
if command -v safe_unalias >/dev/null; then
  safe_unalias \
    gr grs grm grh \
    gbh gbc gdb gdbs \
    gop god goc gob \
    gcc gdc \
    git-tools
fi

# ────────────────────────────────────────────────────────
# Git operation aliases
# ────────────────────────────────────────────────────────

# Reset staged files (equivalent to "git reset")
alias gr='git reset'

# Short aliases for common undo/reset operations
alias grs='git-reset-soft'
alias grm='git-reset-mixed'
alias grh='git-reset-hard'
alias gbh='git-back-head'
alias gbc='git-back-checkout'

# Branch cleanup aliases
alias gdb='git-delete-merged-branches'
alias gdbs='gdb --squash'

# GitHub / GitLab remote open aliases
alias gop='git-open'
alias god='git-open-default-branch'
alias goc='git-open-commit'
alias gob='git-open-branch'

# Commit context alias
alias gcc='git-commit-context'
alias gdc='git-copy-staged'

# ────────────────────────────────────────────────────────
# Git tools CLI entrypoint
# ────────────────────────────────────────────────────────
_git_tools_usage() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  print -r -- "Usage:"
  print -r -- "  git-tools <group> <command> [args]"
  print -r --
  print -r -- "Groups:"
  print -r -- "  utils    zip | copy-staged | root | commit-hash"
  print -r -- "  reset    soft | mixed | hard | undo | back-head | back-checkout | remote"
  print -r -- "  commit   context | to-stash"
  print -r -- "  branch   cleanup"
  print -r -- "  open     repo | branch | default-branch | commit | upstream | normalize-url | push-open"
  print -r --
  print -r -- "Help:"
  print -r -- "  git-tools help"
  print -r -- "  git-tools <group> help"
  print -r --
  print -r -- "Examples:"
  print -r -- "  git-tools utils zip"
  print -r -- "  git-tools reset hard 3"
  print -r -- "  git-tools open commit HEAD"
  return 0
}

_git_tools_group_usage() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset group="${1-}"

  case "$group" in
    utils)
      print -r -- "Usage: git-tools utils <command> [args]"
      print -r -- "  zip | copy-staged | root | commit-hash"
      ;;
    reset)
      print -r -- "Usage: git-tools reset <command> [args]"
      print -r -- "  soft | mixed | hard | undo | back-head | back-checkout | remote"
      ;;
    commit)
      print -r -- "Usage: git-tools commit <command> [args]"
      print -r -- "  context | to-stash"
      ;;
    branch)
      print -r -- "Usage: git-tools branch <command> [args]"
      print -r -- "  cleanup"
      ;;
    open)
      print -r -- "Usage: git-tools open <command> [args]"
      print -r -- "  repo | branch | default-branch | commit | upstream | normalize-url | push-open"
      ;;
    *)
      print -u2 -r -- "Unknown group: $group"
      _git_tools_usage
      return 2
      ;;
  esac
}

git-tools() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset group="${1-}"
  typeset cmd="${2-}"

  case "$group" in
    ''|-h|--help|help|list)
      _git_tools_usage
      return 0
      ;;
    *)
      ;;
  esac

  if [[ -z "$cmd" || "$cmd" == "-h" || "$cmd" == "--help" || "$cmd" == "help" ]]; then
    _git_tools_group_usage "$group"
    return $?
  fi

  shift 2

  case "$group" in
    utils)
      case "$cmd" in
        zip)
          git-zip "$@"
          ;;
        copy-staged|copy)
          git-copy-staged "$@"
          ;;
        root)
          git-root "$@"
          ;;
        commit-hash|hash)
          get_commit_hash "$@"
          ;;
        *)
          print -u2 -r -- "Unknown utils command: $cmd"
          _git_tools_group_usage "$group"
          return 2
          ;;
      esac
      ;;
    reset)
      case "$cmd" in
        soft)
          git-reset-soft "$@"
          ;;
        mixed)
          git-reset-mixed "$@"
          ;;
        hard)
          git-reset-hard "$@"
          ;;
        undo)
          git-reset-undo "$@"
          ;;
        back-head)
          git-back-head "$@"
          ;;
        back-checkout)
          git-back-checkout "$@"
          ;;
        remote)
          git-reset-remote "$@"
          ;;
        *)
          print -u2 -r -- "Unknown reset command: $cmd"
          _git_tools_group_usage "$group"
          return 2
          ;;
      esac
      ;;
    commit)
      case "$cmd" in
        context)
          git-commit-context "$@"
          ;;
        to-stash|stash)
          git-commit-to-stash "$@"
          ;;
        *)
          print -u2 -r -- "Unknown commit command: $cmd"
          _git_tools_group_usage "$group"
          return 2
          ;;
      esac
      ;;
    branch)
      case "$cmd" in
        cleanup|delete-merged)
          git-delete-merged-branches "$@"
          ;;
        *)
          print -u2 -r -- "Unknown branch command: $cmd"
          _git_tools_group_usage "$group"
          return 2
          ;;
      esac
      ;;
    open)
      case "$cmd" in
        repo)
          git-open "$@"
          ;;
        branch)
          git-open-branch "$@"
          ;;
        default|default-branch)
          git-open-default-branch "$@"
          ;;
        commit)
          git-open-commit "$@"
          ;;
        upstream|resolve-upstream)
          git-resolve-upstream "$@"
          ;;
        normalize-url|normalize-remote-url)
          git-normalize-remote-url "$@"
          ;;
        push-open)
          gh-push-open "$@"
          ;;
        *)
          print -u2 -r -- "Unknown open command: $cmd"
          _git_tools_group_usage "$group"
          return 2
          ;;
      esac
      ;;
    *)
      print -u2 -r -- "Unknown group: $group"
      _git_tools_usage
      return 2
      ;;
  esac
}
