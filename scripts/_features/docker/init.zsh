# Feature: docker
#
# Enables:
# - docker-tools (container/compose helpers)
# - docker-aliases (configurable alias sets)
# - Completion for docker/docker-compose/docker-tools (feature-gated via fpath)

typeset feature_dir="${ZSH_SCRIPT_DIR-}/_features/docker"
[[ -n "$feature_dir" && -d "$feature_dir" ]] || return 0

typeset completion_dir="$feature_dir/_completion"
if [[ -d "$completion_dir" ]] && (( ${fpath[(Ie)$completion_dir]} == 0 )); then
  fpath=("$completion_dir" $fpath)
fi

typeset script=''
for script in \
  "$feature_dir/docker-completion.zsh" \
  "$feature_dir/docker-tools.zsh" \
  "$feature_dir/docker-aliases.zsh"
do
  [[ -r "$script" ]] || continue
  if (( $+functions[source_file] )); then
    source_file "$script"
  else
    source "$script"
  fi
done

