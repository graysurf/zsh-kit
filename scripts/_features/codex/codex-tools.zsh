typeset -g CODEX_CLI_MODEL="${CODEX_CLI_MODEL:-gpt-5.1-codex-mini}"
typeset -g CODEX_CLI_REASONING="${CODEX_CLI_REASONING:-medium}"

# codex-tools: Opt-in Codex skill wrappers (feature: codex).
#
# Provides:
# - `codex-tools` (CLI dispatcher)
# - `codex-commit-with-scope`
# - `codex-create-feature-pr`
# - `codex-find-and-fix-bugs`
# - `codex-release-workflow`

# _codex_require_allow_dangerous <caller>
# Guard to prevent running codex with dangerous sandbox bypass unless explicitly enabled.
_codex_require_allow_dangerous() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  local caller=''
  caller="${1-}"
  local allow_dangerous=''
  allow_dangerous="${CODEX_ALLOW_DANGEROUS-}"
  allow_dangerous="${allow_dangerous:l}"
  if [[ "$allow_dangerous" != 'true' ]]; then
    if [[ -n "$caller" ]]; then
      print -u2 -r -- "$caller: disabled (set CODEX_ALLOW_DANGEROUS=true)"
    else
      print -u2 -r -- "codex: disabled (set CODEX_ALLOW_DANGEROUS=true)"
    fi
    return 1
  fi
}

# _codex_exec_dangerous <prompt>
# Run codex exec with the configured model and reasoning level using full sandbox bypass.
_codex_exec_dangerous() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  local prompt=''
  prompt="${1-}"
  if [[ -z "$prompt" ]]; then
    print -u2 -r -- "_codex_exec_dangerous: missing prompt"
    return 1
  fi

  codex exec --dangerously-bypass-approvals-and-sandbox -s workspace-write \
    -m "$CODEX_CLI_MODEL" -c "model_reasoning_effort=\"$CODEX_CLI_REASONING\"" \
    "$prompt"
}

# codex-commit-with-scope [extra prompt...]
# Run the commit-message skill to create a Semantic Commit and report git-scope output.
codex-commit-with-scope() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  _codex_require_allow_dangerous 'codex-commit-with-scope' || return 1

  local extra_prompt=''
  if (( $# )); then
    extra_prompt="$*"
  fi

  local prompt=''
  prompt='Use the commit-message skill.'
  if [[ -n "$extra_prompt" ]]; then
    prompt+=$'\n\nAdditional instructions from user:\n'
    prompt+="$extra_prompt"
  fi

  _codex_exec_dangerous "$prompt"
}

# codex-create-feature-pr [feature request...]
# Run the create-feature-pr skill; prompts for input if no request is provided.
codex-create-feature-pr() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  _codex_require_allow_dangerous 'codex-create-feature-pr' || return 1

  local user_prompt=''
  if (( $# )); then
    user_prompt="$*"
  else
    print -n -r -- "Feature request: "
    IFS= read -r user_prompt || return 1
  fi

  if [[ -z "$user_prompt" ]]; then
    print -u2 -r -- "codex-create-feature-pr: missing feature request"
    return 1
  fi

  local prompt=''
  prompt='Use the create-feature-pr skill.'
  prompt+=$'\n\nFeature request:\n'
  prompt+="$user_prompt"

  _codex_exec_dangerous "$prompt"
}

# codex-find-and-fix-bugs [bug report...]
# Run the find-and-fix-bugs skill; accepts an optional bug report for prioritization.
codex-find-and-fix-bugs() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  _codex_require_allow_dangerous 'codex-find-and-fix-bugs' || return 1

  local user_prompt=''
  if (( $# )); then
    user_prompt="$*"
  else
    print -n -r -- "Bug report (optional): "
    IFS= read -r user_prompt || return 1
  fi

  local prompt=''
  prompt='Use the find-and-fix-bugs skill.'
  if [[ -n "$user_prompt" ]]; then
    prompt+=$'\n\nBug report:\n'
    prompt+="$user_prompt"
  fi

  _codex_exec_dangerous "$prompt"
}

# codex-release-workflow [release request...]
# Run the release-workflow skill; accepts optional release context or constraints.
codex-release-workflow() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  _codex_require_allow_dangerous 'codex-release-workflow' || return 1

  local user_prompt=''
  if (( $# )); then
    user_prompt="$*"
  else
    print -n -r -- "Release request (optional): "
    IFS= read -r user_prompt || return 1
  fi

  local prompt=''
  prompt='Use the release-workflow skill.'
  if [[ -n "$user_prompt" ]]; then
    prompt+=$'\n\nRelease request:\n'
    prompt+="$user_prompt"
  fi

  _codex_exec_dangerous "$prompt"
}

# _codex_tools_usage [fd]
# Print top-level usage for `codex-tools`.
# Usage: _codex_tools_usage [fd]
_codex_tools_usage() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset fd="${1-1}"
  print -u"$fd" -r -- 'Usage: codex-tools <command> [args...]'
  print -u"$fd" -r --
  print -u"$fd" -r -- 'Commands:'
  print -u"$fd" -r -- '  commit-with-scope    Run commit-message skill (with git-scope context)'
  print -u"$fd" -r -- '  create-feature-pr    Run create-feature-pr skill'
  print -u"$fd" -r -- '  find-and-fix-bugs    Run find-and-fix-bugs skill'
  print -u"$fd" -r -- '  release-workflow     Run release-workflow skill'
  print -u"$fd" -r --
  print -u"$fd" -r -- 'Safety: requires CODEX_ALLOW_DANGEROUS=true'
  print -u"$fd" -r -- 'Config: CODEX_CLI_MODEL, CODEX_CLI_REASONING'
  return 0
}

# codex-tools <command> [args...]
# Dispatcher for Codex skill helpers.
# Usage: codex-tools <command> [args...]
codex-tools() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset cmd="${1-}"

  case "$cmd" in
    ''|-h|--help|help|list)
      _codex_tools_usage 1
      return 0
      ;;
    *)
      ;;
  esac

  shift

  case "$cmd" in
    commit-with-scope|commit)
      codex-commit-with-scope "$@"
      ;;
    create-feature-pr|create)
      codex-create-feature-pr "$@"
      ;;
    find-and-fix-bugs|fix-bugs)
      codex-find-and-fix-bugs "$@"
      ;;
    release-workflow|release)
      codex-release-workflow "$@"
      ;;
    *)
      print -u2 -r -- "codex-tools: unknown command: $cmd"
      _codex_tools_usage 2
      return 2
      ;;
  esac
}
