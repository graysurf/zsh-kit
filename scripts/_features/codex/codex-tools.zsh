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
  local allow_dangerous_raw=''
  allow_dangerous_raw="${CODEX_ALLOW_DANGEROUS_ENABLED-}"
  if ! zsh_env::is_true "$allow_dangerous_raw" "CODEX_ALLOW_DANGEROUS_ENABLED"; then
    if [[ -n "$caller" ]]; then
      print -u2 -r -- "$caller: disabled (set CODEX_ALLOW_DANGEROUS_ENABLED=true)"
    else
      print -u2 -r -- "codex: disabled (set CODEX_ALLOW_DANGEROUS_ENABLED=true)"
    fi
    return 1
  fi
}

# _codex_exec_dangerous <prompt> [caller]
# Run codex exec with the configured model and reasoning level using full sandbox bypass.
_codex_exec_dangerous() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  local prompt="${1-}"
  local caller="${2-}"
  [[ -n "$caller" ]] || caller='codex-tools'
  if [[ -z "$prompt" ]]; then
    print -u2 -r -- "_codex_exec_dangerous: missing prompt"
    return 1
  fi

  _codex_require_allow_dangerous "$caller" || return 1

  codex exec --dangerously-bypass-approvals-and-sandbox -s workspace-write \
    -m "$CODEX_CLI_MODEL" -c "model_reasoning_effort=\"$CODEX_CLI_REASONING\"" \
    -- "$prompt"
}

# _codex_tools_semantic_commit_skill_available
# Return 0 when the semantic-commit skill exists locally.
# Usage: _codex_tools_semantic_commit_skill_available
_codex_tools_semantic_commit_skill_available() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset codex_home="${CODEX_HOME-}"
  [[ -n "$codex_home" ]] || return 1

  [[ -f "$codex_home/skills/tools/devex/semantic-commit/SKILL.md" || -f "$codex_home/skills/semantic-commit/SKILL.md" ]]
}

# _codex_tools_semantic_commit_autostage_skill_available
# Return 0 when the semantic-commit-autostage skill exists locally.
# Usage: _codex_tools_semantic_commit_autostage_skill_available
_codex_tools_semantic_commit_autostage_skill_available() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset codex_home="${CODEX_HOME-}"
  [[ -n "$codex_home" ]] || return 1

  [[ -f "$codex_home/skills/automation/semantic-commit-autostage/SKILL.md" || -f "$codex_home/skills/semantic-commit-autostage/SKILL.md" ]]
}

# _codex_tools_commit_with_scope_fallback <push_flag> [extra prompt...]
# Local Conventional Commit fallback for when semantic-commit skill is unavailable.
# Usage: _codex_tools_commit_with_scope_fallback <push_flag> [extra prompt...]
_codex_tools_commit_with_scope_fallback() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset push_flag="${1-}"
  shift || true
  typeset extra_prompt="$*"

  if ! command -v git >/dev/null; then
    print -u2 -r -- "codex-commit-with-scope: missing binary: git"
    return 1
  fi

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    print -u2 -r -- "codex-commit-with-scope: not a git repository"
    return 1
  fi

  typeset staged=''
  staged="$(git -c core.quotepath=false diff --cached --name-only --diff-filter=ACMRTUXB 2>/dev/null || true)"
  if [[ -z "$staged" ]]; then
    print -u2 -r -- "codex-commit-with-scope: no staged changes (stage files then retry)"
    return 1
  fi

  typeset expected_skill_path=''
  if [[ -n "${CODEX_HOME-}" ]]; then
    expected_skill_path="$CODEX_HOME/skills/tools/devex/semantic-commit/SKILL.md"
  fi
  print -u2 -r -- "codex-commit-with-scope: semantic-commit skill not found${expected_skill_path:+: $expected_skill_path}"

  if [[ -n "$extra_prompt" ]]; then
    print -u2 -r -- "codex-commit-with-scope: note: extra prompt is ignored in fallback mode"
  fi

  if (( $+functions[git-scope] )) || command -v git-scope >/dev/null 2>&1; then
    git-scope staged || true
  else
    print -r -- "Staged files:"
    print -r -- "$staged"
  fi

  typeset -a files=("${(@f)staged}")
  typeset -A top=()
  typeset file='' part=''
  for file in "${files[@]}"; do
    [[ -n "$file" ]] || continue
    if [[ "$file" == */* ]]; then
      part="${file%%/*}"
      top["$part"]=1
    else
      top['']=1
    fi
  done

  typeset suggested_scope=''
  if (( ${#top[@]} == 1 )); then
    for part in ${(k)top}; do
      suggested_scope="$part"
    done
    [[ "$suggested_scope" == '' ]] && suggested_scope=''
  elif (( ${#top[@]} == 2 )) && (( ${+top['']} )); then
    for part in ${(k)top}; do
      if [[ -n "$part" ]]; then
        suggested_scope="$part"
      fi
    done
  fi

  typeset commit_type=''
  print -n -r -- "Type [chore]: "
  IFS= read -r commit_type || return 1
  commit_type="${commit_type:l}"
  commit_type="${commit_type//[[:space:]]/}"
  [[ -n "$commit_type" ]] || commit_type='chore'

  typeset scope=''
  if [[ -n "$suggested_scope" ]]; then
    print -n -r -- "Scope (optional) [$suggested_scope]: "
  else
    print -n -r -- "Scope (optional): "
  fi
  IFS= read -r scope || return 1
  scope="${scope//[[:space:]]/}"
  [[ -n "$scope" ]] || scope="$suggested_scope"

  typeset subject=''
  while [[ -z "$subject" ]]; do
    print -n -r -- "Subject: "
    IFS= read -r subject || return 1
    subject="${subject#"${subject%%[![:space:]]*}"}"
    subject="${subject%"${subject##*[![:space:]]}"}"
  done

  typeset header=''
  if [[ -n "$scope" ]]; then
    header="${commit_type}(${scope}): ${subject}"
  else
    header="${commit_type}: ${subject}"
  fi

  print -r -- ""
  print -r -- "Commit message:"
  print -r -- "  $header"
  print -n -r -- "Proceed? [y/N] "
  typeset confirm=''
  IFS= read -r confirm || return 1
  if [[ "$confirm" != [yY] ]]; then
    print -u2 -r -- "Aborted."
    return 1
  fi

  git commit -m "$header" || return 1

  if [[ "$push_flag" == 'true' ]]; then
    git push || return 1
  fi

  if (( $+functions[git-scope] )) || command -v git-scope >/dev/null 2>&1; then
    git-scope commit HEAD || true
  else
    git show -1 --name-status --oneline || true
  fi

  return 0
}

# codex-commit-with-scope [-p] [-a] [extra prompt...]
# Run the semantic-commit skill to create a Semantic Commit and report git-scope output.
# Options:
#   -p    Push to remote after a successful commit.
#   -a, --auto-stage  Use semantic-commit-autostage (autostage all changes) instead of semantic-commit.
codex-commit-with-scope() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  if ! zmodload zsh/zutil 2>/dev/null; then
    print -u2 -r -- "❌ zsh/zutil is required for zparseopts."
    return 1
  fi

  local -A opts=()
  zparseopts -D -E -A opts -- p a -auto-stage || return 1

  local push_flag='false'
  if (( ${+opts[-p]} )); then
    push_flag='true'
  fi

  local auto_stage_flag='false'
  if (( ${+opts[-a]} || ${+opts[--auto-stage]} )); then
    auto_stage_flag='true'
  fi

  _codex_require_allow_dangerous 'codex-commit-with-scope' || return 1

  if ! command -v git >/dev/null; then
    print -u2 -r -- "codex-commit-with-scope: missing binary: git"
    return 1
  fi

  local git_root=''
  if ! git_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    print -u2 -r -- "codex-commit-with-scope: not a git repository"
    return 1
  fi

  if [[ "$auto_stage_flag" == 'true' ]]; then
    git -C "$git_root" add -A || return 1
  else
    local staged=''
    staged="$(git -C "$git_root" -c core.quotepath=false diff --cached --name-only --diff-filter=ACMRTUXB 2>/dev/null || true)"
    if [[ -z "$staged" ]]; then
      print -u2 -r -- "codex-commit-with-scope: no staged changes (stage files then retry)"
      return 1
    fi
  fi

  local extra_prompt=''
  if (( $# )); then
    extra_prompt="$*"
  fi

  local skill_name='semantic-commit'
  if [[ "$auto_stage_flag" == 'true' ]]; then
    skill_name='semantic-commit-autostage'
    if ! _codex_tools_semantic_commit_autostage_skill_available; then
      local expected_skill_path=''
      if [[ -n "${CODEX_HOME-}" ]]; then
        expected_skill_path="$CODEX_HOME/skills/automation/semantic-commit-autostage/SKILL.md"
      fi
      print -u2 -r -- "codex-commit-with-scope: semantic-commit-autostage skill not found${expected_skill_path:+: $expected_skill_path}"
      return 1
    fi
  else
    if ! _codex_tools_semantic_commit_skill_available; then
      _codex_tools_commit_with_scope_fallback "$push_flag" "$extra_prompt"
      return $?
    fi
  fi

  local prompt=''
  prompt="Use the ${skill_name} skill."

  if [[ "$push_flag" == 'true' ]]; then
    prompt+=$'\n\nFurthermore, please push the committed changes to the remote repository.'
  fi

  if [[ -n "$extra_prompt" ]]; then
    prompt+=$'\n\nAdditional instructions from user:\n'
    prompt+="$extra_prompt"
  fi

  _codex_exec_dangerous "$prompt" 'codex-commit-with-scope'
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

  local prompt_content=''
  prompt_content=$(cat -- "$prompt_file")

  # Replace $ARGUMENTS with user query
  local final_prompt="${prompt_content//\$ARGUMENTS/$user_query}"

  _codex_exec_dangerous "$final_prompt" "codex-tools:${template_name}"
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

  typeset secrets_file="$feature_dir/_codex-secret.zsh"
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

  typeset use_async='false'
  typeset arg=''
  for arg in "$@"; do
    if [[ "$arg" == '--' ]]; then
      break
    fi
    if [[ "$arg" == '--async' ]]; then
      use_async='true'
      break
    fi
  done

  _codex_tools_require_secrets || return 1

  if [[ "$use_async" != 'true' ]]; then
    codex-rate-limits "$@"
    return $?
  fi

  if ! typeset -f codex-rate-limits-async >/dev/null 2>&1; then
    print -u2 -r -- "codex-tools: codex-rate-limits-async is not available (update codex secrets helpers)"
    return 1
  fi

  typeset clear_cache='false'
  typeset cached_mode='false'
  typeset -a async_args=()

  while (( $# > 0 )); do
    case "${1-}" in
      --async)
        shift
        ;;
      -c)
        clear_cache='true'
        shift
        ;;
      --all)
        # Async always queries all secrets under CODEX_SECRET_DIR.
        shift
        ;;
      --cached)
        cached_mode='true'
        async_args+=( --cached )
        shift
        ;;
      -j|--jobs)
        if (( $# < 2 )); then
          print -u2 -r -- "codex-tools: rate-limits --async: missing value for ${1-}"
          return 64
        fi
        async_args+=( "${1-}" "${2-}" )
        shift 2 || true
        ;;
      --jobs=*)
        async_args+=( "${1-}" )
        shift
        ;;
      -d|--debug|-h|--help|--no-refresh-auth|--)
        async_args+=( "${1-}" )
        shift
        ;;
      --json|--one-line)
        print -u2 -r -- "codex-tools: rate-limits --async does not support ${1-}"
        return 64
        ;;
      -*)
        print -u2 -r -- "codex-tools: rate-limits --async: unknown option: ${1-}"
        return 64
        ;;
      *)
        print -u2 -r -- "codex-tools: rate-limits --async does not accept positional args: ${1-}"
        print -u2 -r -- "codex-tools: hint: async always queries all secrets under CODEX_SECRET_DIR"
        return 64
        ;;
    esac
  done

  if [[ "${clear_cache}" == 'true' && "${cached_mode}" == 'true' ]]; then
    print -u2 -r -- "codex-tools: rate-limits --async: -c is not compatible with --cached"
    return 64
  fi

  if [[ "${clear_cache}" == 'true' ]]; then
    _codex_rate_limits_clear_starship_cache || return 1
  fi

  codex-rate-limits-async "${async_args[@]}"
}

# _codex_tools_usage [fd]
# Print top-level usage for `codex-tools`.
# Usage: _codex_tools_usage [fd]
_codex_tools_usage() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset fd="${1-1}"
  print -u"$fd" -r -- 'Usage:'
  print -u"$fd" -r -- '  codex-tools <command> [args...]'
  print -u"$fd" -r -- '  codex-tools <prompt...>'
  print -u"$fd" -r -- '  codex-tools -- <prompt...>   (force prompt mode)'
  print -u"$fd" -r --
  print -u"$fd" -r -- 'Commands:'
  print -u"$fd" -r -- '  prompt [prompt...]                             Run a raw prompt (useful when prompt starts with a command word)'
  print -u"$fd" -r -- '  commit-with-scope [-p] [-a] [extra prompt...]  Run semantic-commit skill (with git-scope context)'
  print -u"$fd" -r -- '    -p                                           Push to remote after commit'
  print -u"$fd" -r -- '    -a, --auto-stage                             Use semantic-commit-autostage (autostage all changes)'
  print -u"$fd" -r -- '  auto-refresh                                   Run codex-auto-refresh (token refresh helper)'
  print -u"$fd" -r -- '  rate-limits                                    Run codex-rate-limits (supports --async/--jobs for concurrent all-accounts table)'
  print -u"$fd" -r -- '  advice [question]                              Get actionable engineering advice'
  print -u"$fd" -r -- '  knowledge [concept]                            Get clear explanation and angles for a concept'
  print -u"$fd" -r --
  print -u"$fd" -r -- 'Safety: codex exec requires CODEX_ALLOW_DANGEROUS_ENABLED=true'
  print -u"$fd" -r -- 'Config: CODEX_CLI_MODEL, CODEX_CLI_REASONING'
  return 0
}

# _codex_tools_run_raw_prompt [prompt...]
# Run codex with a raw prompt string.
_codex_tools_run_raw_prompt() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  local user_prompt="$*"

  if [[ -z "$user_prompt" ]]; then
    print -n -r -- "Prompt: "
    IFS= read -r user_prompt || return 1
  fi

  if [[ -z "$user_prompt" ]]; then
    print -u2 -r -- "codex-tools: missing prompt"
    return 1
  fi

  _codex_exec_dangerous "$user_prompt" 'codex-tools:prompt'
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
    --|prompt)
      _codex_tools_run_raw_prompt "$@"
      ;;
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
      _codex_tools_run_raw_prompt "$cmd" "$@"
      ;;
  esac
}
