# ────────────────────────────────────────────────────────
# Aliases and Unalias
# ────────────────────────────────────────────────────────
if command -v safe_unalias >/dev/null; then
  safe_unalias \
    gr grs grm grh \
    gbh gbc gdb gdbs \
    gcc gccj gdc \
    gt gtu gtr gtc gtb gti \
    gtuz gtuc gtur gtuh \
    gtrs gtrm gtrh gtru gtrbh gtrbc gtrr \
    gtcc gtcj gtcs \
    gtbc gtip gth \
    git-tools
fi

# ────────────────────────────────────────────────────────
# Git operation aliases
# ────────────────────────────────────────────────────────

# gr
# Alias of `git reset` (commonly used to unstage paths).
# Usage: gr [args...]
alias gr='git reset'

# grs [N]
# Alias of `git-reset-soft`.
# Usage: grs [N]
alias grs='git-reset-soft'

# grm [N]
# Alias of `git-reset-mixed`.
# Usage: grm [N]
alias grm='git-reset-mixed'

# grh [N]
# Alias of `git-reset-hard` (DANGEROUS).
# Usage: grh [N]
# Safety:
# - Discards tracked staged/unstaged changes; untracked files are NOT removed.
alias grh='git-reset-hard'

# gbh
# Alias of `git-back-head`.
# Usage: gbh
alias gbh='git-back-head'

# gbc
# Alias of `git-back-checkout`.
# Usage: gbc
alias gbc='git-back-checkout'

# gdb
# Alias of `git-delete-merged-branches`.
# Usage: gdb [-b|--base <ref>] [-s|--squash]
# Safety:
# - Deletes local branches after confirmation; review the list before proceeding.
alias gdb='git-delete-merged-branches'

# gdbs
# Alias of `gdb --squash`.
# Usage: gdbs [-b|--base <ref>]
# Safety:
# - Deletes local branches after confirmation; review the list before proceeding.
alias gdbs='gdb --squash'

# gcc
# Alias of `git-commit-context`.
# Usage: gcc [--stdout|--both] [--no-color]
alias gcc='git-commit-context'

# gccj
# Alias of `git-commit-context-json`.
# Usage: gccj [--stdout|--both] [--pretty] [--bundle] [--out-dir <path>]
alias gccj='git-commit-context-json'

# gdc
# Alias of `git-copy-staged`.
# Usage: gdc [--stdout|--both]
alias gdc='git-copy-staged'

# ────────────────────────────────────────────────────────
# git-tools aliases (gt*)
# ────────────────────────────────────────────────────────

# gt
# Alias of `git-tools`.
# Usage: gt <group> <command> [args...]
alias gt='git-tools'

# gth
# Alias of `git-tools help`.
# Usage: gth
alias gth='git-tools help'

# gtu
# Alias of `git-tools utils`.
# Usage: gtu <command> [args...]
alias gtu='git-tools utils'

# gtr
# Alias of `git-tools reset`.
# Usage: gtr <command> [args...]
alias gtr='git-tools reset'

# gtc
# Alias of `git-tools commit`.
# Usage: gtc <command> [args...]
alias gtc='git-tools commit'

# gtb
# Alias of `git-tools branch`.
# Usage: gtb <command> [args...]
alias gtb='git-tools branch'

# gti
# Alias of `git-tools ci`.
# Usage: gti <command> [args...]
alias gti='git-tools ci'

# gtuz
# Alias of `git-tools utils zip`.
# Usage: gtuz
alias gtuz='git-tools utils zip'

# gtuc
# Alias of `git-tools utils copy-staged`.
# Usage: gtuc [args...]
alias gtuc='git-tools utils copy-staged'

# gtur
# Alias of `git-tools utils root`.
# Usage: gtur
alias gtur='git-tools utils root'

# gtuh
# Alias of `git-tools utils commit-hash`.
# Usage: gtuh [ref]
alias gtuh='git-tools utils commit-hash'

# gtrs
# Alias of `git-tools reset soft`.
# Usage: gtrs [N]
alias gtrs='git-tools reset soft'

# gtrm
# Alias of `git-tools reset mixed`.
# Usage: gtrm [N]
alias gtrm='git-tools reset mixed'

# gtrh
# Alias of `git-tools reset hard` (DANGEROUS).
# Usage: gtrh [N]
alias gtrh='git-tools reset hard'

# gtru
# Alias of `git-tools reset undo`.
# Usage: gtru
alias gtru='git-tools reset undo'

# gtrbh
# Alias of `git-tools reset back-head`.
# Usage: gtrbh
alias gtrbh='git-tools reset back-head'

# gtrbc
# Alias of `git-tools reset back-checkout`.
# Usage: gtrbc
alias gtrbc='git-tools reset back-checkout'

# gtrr
# Alias of `git-tools reset remote`.
# Usage: gtrr [args...]
alias gtrr='git-tools reset remote'

# gtcc
# Alias of `git-tools commit context`.
# Usage: gtcc [args...]
alias gtcc='git-tools commit context'

# gtcj
# Alias of `git-tools commit context-json`.
# Usage: gtcj [args...]
alias gtcj='git-tools commit context-json'

# gtcs
# Alias of `git-tools commit to-stash`.
# Usage: gtcs [commit]
alias gtcs='git-tools commit to-stash'

# gtbc
# Alias of `git-tools branch cleanup`.
# Usage: gtbc [args...]
alias gtbc='git-tools branch cleanup'

# gtip
# Alias of `git-tools ci pick`.
# Usage: gtip [target] [commit-range] [name]
alias gtip='git-tools ci pick'

# ────────────────────────────────────────────────────────
# Git tools CLI entrypoint
# ────────────────────────────────────────────────────────
# _git_tools_usage
# Print top-level usage for `git-tools`.
# Usage: _git_tools_usage
_git_tools_usage() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  print -r -- "Usage:"
  print -r -- "  git-tools <group> <command> [args]"
  print -r --
  print -r -- "Groups:"
  print -r -- "  utils    zip | copy-staged | root | commit-hash"
  print -r -- "  reset    soft | mixed | hard | undo | back-head | back-checkout | remote"
  print -r -- "  commit   context | context-json | to-stash"
  print -r -- "  branch   cleanup"
  print -r -- "  ci       pick"
  print -r --
  print -r -- "Help:"
  print -r -- "  git-tools help"
  print -r -- "  git-tools <group> help"
  print -r --
  print -r -- "Examples:"
  print -r -- "  git-tools utils zip"
  print -r -- "  git-tools reset hard 3"
  return 0
}

# _git_tools_group_usage <group>
# Print `git-tools <group>` usage.
# Usage: _git_tools_group_usage <group>
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
      print -r -- "  context | context-json | to-stash"
      ;;
    branch)
      print -r -- "Usage: git-tools branch <command> [args]"
      print -r -- "  cleanup"
      ;;
    ci)
      print -r -- "Usage: git-tools ci <command> [args]"
      print -r -- "  pick"
      ;;
    *)
      print -u2 -r -- "Unknown group: $group"
      _git_tools_usage
      return 2
      ;;
  esac
}

# git-tools <group> <command> [args...]
# Dispatcher for git helper subcommands.
# Usage: git-tools <group> <command> [args...]
# Notes:
# - Groups: utils, reset, commit, branch
# - Run `git-tools help` or `git-tools <group> help` for subcommand lists.
# Examples:
#   git-tools reset hard 3
git-tools() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset group="${1-}"
  typeset cmd="${2-}"

  case "$group" in
    ''|-h|--help|help)
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
        context-json|context_json|contextjson|json)
          git-commit-context-json "$@"
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
    ci)
      case "$cmd" in
        pick)
          git-pick "$@"
          ;;
        *)
          print -u2 -r -- "Unknown ci command: $cmd"
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
