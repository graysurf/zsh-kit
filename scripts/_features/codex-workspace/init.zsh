# Feature: codex-workspace
#
# Enables:
# - codex-workspace (Dev Containers / workspace container helper)
# - codex-workspace-* helpers (rm/refresh/reset)
# - Completion for codex-workspace (feature-gated via fpath)

typeset feature_dir="${ZSH_SCRIPT_DIR-}/_features/codex-workspace"
[[ -n "$feature_dir" && -d "$feature_dir" ]] || return 0

typeset completion_dir="$feature_dir/_completion"
if [[ -d "$completion_dir" ]] && (( ${fpath[(Ie)$completion_dir]} == 0 )); then
  fpath=("$completion_dir" $fpath)
fi

typeset script=''
for script in \
  "$feature_dir/repo-reset.zsh" \
  "$feature_dir/workspace-rm.zsh" \
  "$feature_dir/workspace-launcher.zsh"
do
  [[ -r "$script" ]] || continue
  if (( $+functions[source_file] )); then
    source_file "$script"
  else
    source "$script"
  fi
done

