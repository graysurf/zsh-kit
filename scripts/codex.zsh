typeset -g CODEX_CLI_MODEL="${CODEX_CLI_MODEL:-gpt-5.1-codex-mini}"
typeset -g CODEX_CLI_REASONING="${CODEX_CLI_REASONING:-medium}"

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
