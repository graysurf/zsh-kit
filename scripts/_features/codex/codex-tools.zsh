typeset -g CODEX_CLI_MODEL="${CODEX_CLI_MODEL:-gpt-5.1-codex-mini}"
typeset -g CODEX_CLI_REASONING="${CODEX_CLI_REASONING:-medium}"

if command -v safe_unalias >/dev/null; then
  safe_unalias \
    cx
fi

# cx
# Alias of `codex-tools`.
# Usage: cx <command> [args...]
alias cx='codex-tools'

# codex-tools: Opt-in Codex skill wrappers (feature: codex).
#
# Provides:
# - `codex-tools` (CLI dispatcher, alias `cx`)
# - `codex-commit-with-scope`
# - `codex-advice`
# - `codex-knowledge`
# - `codex-tools auto-refresh`
# - `codex-tools rate-limits`

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
    -- "$prompt"
}

# codex-commit-with-scope [-p] [extra prompt...]
# Run the semantic-commit skill to create a Semantic Commit and report git-scope output.
# Options:
#   -p    Push to remote after a successful commit.
codex-commit-with-scope() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  if ! zmodload zsh/zutil 2>/dev/null; then
    print -u2 -r -- "❌ zsh/zutil is required for zparseopts."
    return 1
  fi

  local -A opts
  zparseopts -D -E -A opts -- p || return 1

  _codex_require_allow_dangerous 'codex-commit-with-scope' || return 1

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

  _codex_exec_dangerous "$prompt"
}

# _codex_tools_run_prompt <template_name> [question...]
# Run codex with a prompt template and user question.
_codex_tools_run_prompt() {
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
    print -u2 -r -- "codex-tools: missing question"
    return 1
  fi

  local prompts_dir=''
  prompts_dir="$(_codex_tools_prompts_dir)" || return 1
  local prompt_file="$prompts_dir/${template_name}.md"

  if [[ ! -f "$prompt_file" ]]; then
    print -u2 -r -- "codex-tools: prompt template not found: $prompt_file"
    return 1
  fi

  local prompt_content
  prompt_content=$(cat -- "$prompt_file")

  # Replace $ARGUMENTS with user query
  local final_prompt="${prompt_content//\$ARGUMENTS/$user_query}"

  _codex_exec_dangerous "$final_prompt"
}

# codex-advice [question...]
# Run actionable-advice prompt.
codex-advice() {
  _codex_tools_run_prompt "actionable-advice" "$@"
}

# codex-knowledge [question...]
# Run actionable-knowledge prompt.
codex-knowledge() {
  _codex_tools_run_prompt "actionable-knowledge" "$@"
}

# _codex_tools_feature_dir
# Print the codex feature directory path.
# Usage: _codex_tools_feature_dir
_codex_tools_feature_dir() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset script_dir="${ZSH_SCRIPT_DIR-}"
  if [[ -z "$script_dir" ]]; then
    typeset zdotdir="${ZDOTDIR-}"
    if [[ -z "$zdotdir" ]]; then
      typeset home="${HOME-}"
      [[ -n "$home" ]] || return 1
      zdotdir="$home/.config/zsh"
    fi
    script_dir="$zdotdir/scripts"
  fi

  typeset feature_dir="$script_dir/_features/codex"
  [[ -d "$feature_dir" ]] || return 1

  print -r -- "$feature_dir"
  return 0
}

# _codex_tools_prompts_dir
# Print the prompts directory path.
# Usage: _codex_tools_prompts_dir
_codex_tools_prompts_dir() {
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
  if [[ -d "$prompts_dir" ]]; then
    print -r -- "$prompts_dir"
    return 0
  fi

  # Back-compat: older layout stored prompts inside the feature directory.
  typeset feature_dir=''
  feature_dir="$(_codex_tools_feature_dir)" || return 1

  prompts_dir="$feature_dir/prompts"
  [[ -d "$prompts_dir" ]] || return 1

  print -r -- "$prompts_dir"
  return 0
}

# _codex_tools_run_auto_refresh [args...]
# Run codex-auto-refresh (prefers the in-shell function; falls back to executing the script).
_codex_tools_run_auto_refresh() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  if typeset -f codex-auto-refresh >/dev/null 2>&1; then
    codex-auto-refresh "$@"
    return $?
  fi

  typeset feature_dir=''
  feature_dir="$(_codex_tools_feature_dir)" || {
    print -u2 -r -- "codex-tools: feature dir not found (expected: \$ZSH_SCRIPT_DIR/_features/codex)"
    return 1
  }

  typeset script="$feature_dir/codex-auto-refresh.zsh"
  if [[ ! -f "$script" ]]; then
    print -u2 -r -- "codex-tools: missing script: $script"
    return 1
  fi

  zsh -f -- "$script" "$@"
}

# _codex_tools_require_secrets
# Ensure codex secret helper functions are loaded.
_codex_tools_require_secrets() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  if typeset -f codex-rate-limits >/dev/null 2>&1; then
    return 0
  fi

  typeset feature_dir=''
  feature_dir="$(_codex_tools_feature_dir)" || {
    print -u2 -r -- "codex-tools: feature dir not found (expected: \$ZSH_SCRIPT_DIR/_features/codex)"
    return 1
  }

  typeset secrets_file="$feature_dir/secrets/_codex-secret.zsh"
  if [[ ! -f "$secrets_file" ]]; then
    print -u2 -r -- "codex-tools: missing secrets helper: $secrets_file"
    return 1
  fi

  source "$secrets_file"
  if ! typeset -f codex-rate-limits >/dev/null 2>&1; then
    print -u2 -r -- "codex-tools: failed to load codex-rate-limits"
    return 1
  fi

  return 0
}

# _codex_tools_run_rate_limits [args...]
# Run codex-rate-limits (loads secret helpers lazily when needed).
_codex_tools_run_rate_limits() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  _codex_tools_require_secrets || return 1
  codex-rate-limits "$@"
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
  print -u"$fd" -r -- '  commit-with-scope [-p] [extra prompt...]  Run semantic-commit skill (with git-scope context)'
  print -u"$fd" -r -- '    -p                                      Push to remote after commit'
  print -u"$fd" -r -- '  auto-refresh                              Run codex-auto-refresh (token refresh helper)'
  print -u"$fd" -r -- '  rate-limits                               Run codex-rate-limits (wham/usage; supports -c/-d/--cached/--no-refresh-auth/--all/--json)'
  print -u"$fd" -r -- '  advice [question]                         Get actionable engineering advice'
  print -u"$fd" -r -- '  knowledge [concept]                       Get clear explanation and angles for a concept'
  print -u"$fd" -r --
  print -u"$fd" -r -- 'Safety: some commands require CODEX_ALLOW_DANGEROUS=true'
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
    auto-refresh)
      _codex_tools_run_auto_refresh "$@"
      ;;
    rate-limits)
      _codex_tools_run_rate_limits "$@"
      ;;
    advice)
      codex-advice "$@"
      ;;
    knowledge)
      codex-knowledge "$@"
      ;;
    *)
      print -u2 -r -- "codex-tools: unknown command: $cmd"
      _codex_tools_usage 2
      return 2
      ;;
  esac
}
