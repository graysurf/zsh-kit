# Feature: codex
#
# Enables:
# - codex secrets helpers (codex-use/codex-refresh-auth/codex-auto-refresh)
# - codex-tools (Codex skill wrappers; guarded by CODEX_ALLOW_DANGEROUS_ENABLED)
# - codex-starship (Starship custom module helper; guarded by CODEX_STARSHIP_ENABLED)
# - Completion for codex-tools (optional; feature-gated via fpath)

typeset feature_dir="${ZSH_SCRIPT_DIR-}/_features/codex"
[[ -n "$feature_dir" && -d "$feature_dir" ]] || return 0

typeset completion_dir="$feature_dir/_completion"
if [[ -d "$completion_dir" ]] && (( ${fpath[(Ie)$completion_dir]} == 0 )); then
  fpath=("$completion_dir" $fpath)
fi

typeset script=''
	for script in \
	  "$feature_dir/alias.zsh" \
	  "$feature_dir/codex-secret.zsh" \
	  "$feature_dir/codex-auto-refresh.zsh" \
	  "$feature_dir/codex-starship.zsh" \
	  "$feature_dir/codex-tools.zsh"
do
  [[ -r "$script" ]] || continue
  if (( $+functions[source_file] )); then
    source_file "$script"
  else
    source "$script"
  fi
done
