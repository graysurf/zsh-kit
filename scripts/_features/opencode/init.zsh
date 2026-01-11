# Feature: opencode
#
# Enables:
# - opencode-tools (Prompt helpers)
# - Completion for opencode-tools (optional; feature-gated via fpath)

typeset feature_dir="${ZSH_SCRIPT_DIR-}/_features/opencode"
[[ -n "$feature_dir" && -d "$feature_dir" ]] || return 0

typeset completion_dir="$feature_dir/_completion"
if [[ -d "$completion_dir" ]] && (( ${fpath[(Ie)$completion_dir]} == 0 )); then
  fpath=("$completion_dir" $fpath)
fi

typeset script=''
for script in \
  "$feature_dir/opencode-tools.zsh"
do
  [[ -r "$script" ]] || continue
  if (( $+functions[source_file] )); then
    source_file "$script"
  else
    source "$script"
  fi
done

