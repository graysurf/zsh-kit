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

# _opencode_tools_semantic_commit_skill_available
# Return 0 when the semantic-commit skill exists locally.
# Usage: _opencode_tools_semantic_commit_skill_available
_opencode_tools_semantic_commit_skill_available() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset codex_home="${CODEX_HOME-}"
  [[ -n "$codex_home" ]] || return 1

  [[ -f "$codex_home/skills/tools/devex/semantic-commit/SKILL.md" || -f "$codex_home/skills/semantic-commit/SKILL.md" ]]
}

# _opencode_tools_semantic_commit_autostage_skill_available
# Return 0 when the semantic-commit-autostage skill exists locally.
# Usage: _opencode_tools_semantic_commit_autostage_skill_available
_opencode_tools_semantic_commit_autostage_skill_available() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset codex_home="${CODEX_HOME-}"
  [[ -n "$codex_home" ]] || return 1

  [[ -f "$codex_home/skills/automation/semantic-commit-autostage/SKILL.md" || -f "$codex_home/skills/semantic-commit-autostage/SKILL.md" ]]
}

# _opencode_tools_commit_with_scope_fallback <push_flag> [extra prompt...]
# Local Conventional Commit fallback for when semantic-commit skill is unavailable.
# Usage: _opencode_tools_commit_with_scope_fallback <push_flag> [extra prompt...]
_opencode_tools_commit_with_scope_fallback() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset push_flag="${1-}"
  shift || true
  typeset extra_prompt="$*"

  if ! command -v git >/dev/null; then
    print -u2 -r -- "opencode-commit-with-scope: missing binary: git"
    return 1
  fi

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    print -u2 -r -- "opencode-commit-with-scope: not a git repository"
    return 1
  fi

  typeset staged=''
  staged="$(git -c core.quotepath=false diff --cached --name-only --diff-filter=ACMRTUXB 2>/dev/null || true)"
  if [[ -z "$staged" ]]; then
    print -u2 -r -- "opencode-commit-with-scope: no staged changes (stage files then retry)"
    return 1
  fi

  typeset expected_skill_path=''
  if [[ -n "${CODEX_HOME-}" ]]; then
    expected_skill_path="$CODEX_HOME/skills/tools/devex/semantic-commit/SKILL.md"
  fi
  print -u2 -r -- "opencode-commit-with-scope: semantic-commit skill not found${expected_skill_path:+: $expected_skill_path}"

  if [[ -n "$extra_prompt" ]]; then
    print -u2 -r -- "opencode-commit-with-scope: note: extra prompt is ignored in fallback mode"
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

# opencode-commit-with-scope [-p] [-a|--auto-stage] [extra prompt...]
# Run the semantic-commit skill to create a Semantic Commit and report git-scope output.
# Options:
#   -p    Push to remote after a successful commit.
#   -a, --auto-stage  Use semantic-commit-autostage (autostage all changes) instead of semantic-commit.
opencode-commit-with-scope() {
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

  if ! command -v git >/dev/null; then
    print -u2 -r -- "opencode-commit-with-scope: missing binary: git"
    return 1
  fi

  local git_root=''
  if ! git_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    print -u2 -r -- "opencode-commit-with-scope: not a git repository"
    return 1
  fi

  git -C "$git_root" add -A || return 1

  local extra_prompt=''
  if (( $# )); then
    extra_prompt="$*"
  fi

  local skill_name='semantic-commit'
  if [[ "$auto_stage_flag" == 'true' ]]; then
    skill_name='semantic-commit-autostage'
    if ! _opencode_tools_semantic_commit_autostage_skill_available; then
      local expected_skill_path=''
      if [[ -n "${CODEX_HOME-}" ]]; then
        expected_skill_path="$CODEX_HOME/skills/automation/semantic-commit-autostage/SKILL.md"
      fi
      print -u2 -r -- "opencode-commit-with-scope: semantic-commit-autostage skill not found${expected_skill_path:+: $expected_skill_path}"
      return 1
    fi
  else
    if ! _opencode_tools_semantic_commit_skill_available; then
      _opencode_tools_commit_with_scope_fallback "$push_flag" "$extra_prompt"
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

  local prompt_content=''
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
  print -u"$fd" -r -- 'Usage:'
  print -u"$fd" -r -- '  opencode-tools <command> [args...]'
  print -u"$fd" -r -- '  opencode-tools <prompt...>'
  print -u"$fd" -r -- '  opencode-tools -- <prompt...>   (force prompt mode)'
  print -u"$fd" -r --
  print -u"$fd" -r -- 'Commands:'
  print -u"$fd" -r -- '  prompt [prompt...]                             Run a raw prompt (useful when prompt starts with a command word)'
  print -u"$fd" -r -- '  commit-with-scope [-p] [-a] [extra prompt...]  Run semantic-commit skill (with git-scope context)'
  print -u"$fd" -r -- '    -p                                           Push to remote after commit'
  print -u"$fd" -r -- '    -a, --auto-stage                             Use semantic-commit-autostage (autostage all changes)'
  print -u"$fd" -r -- '  advice [question]                              Get actionable engineering advice'
  print -u"$fd" -r -- '  knowledge [concept]                            Get clear explanation and angles for a concept'
  print -u"$fd" -r --
  print -u"$fd" -r -- 'Config: OPENCODE_CLI_MODEL, OPENCODE_CLI_VARIANT'
  return 0
}

# _opencode_tools_run_raw_prompt [prompt...]
# Run opencode with a raw prompt string.
_opencode_tools_run_raw_prompt() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  local user_prompt="$*"

  if [[ -z "$user_prompt" ]]; then
    print -n -r -- "Prompt: "
    IFS= read -r user_prompt || return 1
  fi

  if [[ -z "$user_prompt" ]]; then
    print -u2 -r -- "opencode-tools: missing prompt"
    return 1
  fi

  _opencode_tools_exec "$user_prompt" 'opencode-tools:prompt'
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
    --|prompt)
      _opencode_tools_run_raw_prompt "$@"
      ;;
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
      _opencode_tools_run_raw_prompt "$cmd" "$@"
      ;;
  esac
}
