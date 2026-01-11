typeset -g OPENCODE_CLI_MODEL="${OPENCODE_CLI_MODEL:-}"
typeset -g OPENCODE_CLI_VARIANT="${OPENCODE_CLI_VARIANT:-}"

if command -v safe_unalias >/dev/null; then
  safe_unalias \
    oc
fi

# oc
# Alias of `opencode-tools`.
# Usage: oc <command> [args...]
alias oc='opencode-tools'

# opencode-tools: Prompt helpers (feature: opencode).
#
# Provides:
# - `opencode-tools` (CLI dispatcher, alias `oc`)
# - `opencode-commit-with-scope`
# - `opencode-advice`
# - `opencode-knowledge`

# _opencode_tools_exec <prompt> [title]
# Run opencode with the configured model/variant.
_opencode_tools_exec() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  if ! command -v opencode >/dev/null; then
    print -u2 -r -- "opencode-tools: missing binary: opencode"
    return 1
  fi

  local prompt="${1-}"
  local title="${2-}"

  if [[ -z "$prompt" ]]; then
    print -u2 -r -- "_opencode_tools_exec: missing prompt"
    return 1
  fi

  local -a cmd=(opencode run)

  local model="${OPENCODE_CLI_MODEL-}"
  if [[ -n "$model" ]]; then
    cmd+=(-m "$model")
  fi

  local variant="${OPENCODE_CLI_VARIANT-}"
  if [[ -n "$variant" ]]; then
    cmd+=(--variant "$variant")
  fi

  if [[ -n "$title" ]]; then
    cmd+=(--title "$title")
  fi

  cmd+=(-- "$prompt")
  "${cmd[@]}"
}

# opencode-commit-with-scope [-p] [extra prompt...]
# Run the semantic-commit skill to create a Semantic Commit and report git-scope output.
# Options:
#   -p    Push to remote after a successful commit.
opencode-commit-with-scope() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  if ! zmodload zsh/zutil 2>/dev/null; then
    print -u2 -r -- "❌ zsh/zutil is required for zparseopts."
    return 1
  fi

  local -A opts
  zparseopts -D -E -A opts -- p || return 1

  local extra_prompt=''
  if (( $# )); then
    extra_prompt="$*"
  fi

  local prompt=''
  prompt='Use the semantic-commit skill.'

  if (( ${+opts[-p]} )); then
    prompt+=$'\n\nFurthermore, please push the committed changes to the remote repository.'
  fi

  if [[ -n "$extra_prompt" ]]; then
    prompt+=$'\n\nAdditional instructions from user:\n'
    prompt+="$extra_prompt"
  fi

  _opencode_tools_exec "$prompt" 'opencode-tools:commit-with-scope'
}

# _opencode_tools_prompts_dir
# Print the prompts directory path.
# Usage: _opencode_tools_prompts_dir
_opencode_tools_prompts_dir() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset zdotdir="${ZDOTDIR-}"
  if [[ -z "$zdotdir" ]]; then
    typeset script_dir="${ZSH_SCRIPT_DIR-}"
    if [[ -n "$script_dir" ]]; then
      zdotdir="${script_dir:h}"
    else
      typeset home="${HOME-}"
      [[ -n "$home" ]] || return 1
      zdotdir="$home/.config/zsh"
    fi
  fi

  typeset prompts_dir="$zdotdir/prompts"
  [[ -d "$prompts_dir" ]] || return 1

  print -r -- "$prompts_dir"
  return 0
}

# _opencode_tools_run_prompt <template_name> [question...]
# Run opencode with a prompt template and user question.
_opencode_tools_run_prompt() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  local template_name="${1-}"
  shift
  local user_query="$*"

  if [[ -z "$user_query" ]]; then
    print -n -r -- "Question: "
    IFS= read -r user_query || return 1
  fi

  if [[ -z "$user_query" ]]; then
    print -u2 -r -- "opencode-tools: missing question"
    return 1
  fi

  local prompts_dir=''
  prompts_dir="$(_opencode_tools_prompts_dir)" || {
    print -u2 -r -- "opencode-tools: prompts dir not found (expected: \$ZDOTDIR/prompts)"
    return 1
  }

  local prompt_file="$prompts_dir/${template_name}.md"
  if [[ ! -f "$prompt_file" ]]; then
    print -u2 -r -- "opencode-tools: prompt template not found: $prompt_file"
    return 1
  fi

  local prompt_content
  prompt_content=$(cat -- "$prompt_file")

  # Replace $ARGUMENTS with user query
  local final_prompt="${prompt_content//\$ARGUMENTS/$user_query}"

  _opencode_tools_exec "$final_prompt" "opencode-tools:$template_name"
}

# opencode-advice [question...]
# Run actionable-advice prompt.
opencode-advice() {
  _opencode_tools_run_prompt "actionable-advice" "$@"
}

# opencode-knowledge [question...]
# Run actionable-knowledge prompt.
opencode-knowledge() {
  _opencode_tools_run_prompt "actionable-knowledge" "$@"
}

# _opencode_tools_usage [fd]
# Print top-level usage for `opencode-tools`.
# Usage: _opencode_tools_usage [fd]
_opencode_tools_usage() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset fd="${1-1}"
  print -u"$fd" -r -- 'Usage: opencode-tools <command> [args...]'
  print -u"$fd" -r --
  print -u"$fd" -r -- 'Commands:'
  print -u"$fd" -r -- '  commit-with-scope [-p] [extra prompt...]  Run semantic-commit skill (with git-scope context)'
  print -u"$fd" -r -- '    -p                                      Push to remote after commit'
  print -u"$fd" -r -- '  advice [question]                         Get actionable engineering advice'
  print -u"$fd" -r -- '  knowledge [concept]                       Get clear explanation and angles for a concept'
  print -u"$fd" -r --
  print -u"$fd" -r -- 'Config: OPENCODE_CLI_MODEL, OPENCODE_CLI_VARIANT'
  return 0
}

# opencode-tools <command> [args...]
# Dispatcher for OpenCode prompt helpers.
# Usage: opencode-tools <command> [args...]
opencode-tools() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset cmd="${1-}"

  case "$cmd" in
    ''|-h|--help|help|list)
      _opencode_tools_usage 1
      return 0
      ;;
    *)
      ;;
  esac

  shift

  case "$cmd" in
    commit-with-scope|commit)
      opencode-commit-with-scope "$@"
      ;;
    advice)
      opencode-advice "$@"
      ;;
    knowledge)
      opencode-knowledge "$@"
      ;;
    *)
      print -u2 -r -- "opencode-tools: unknown command: $cmd"
      _opencode_tools_usage 2
      return 2
      ;;
  esac
}
