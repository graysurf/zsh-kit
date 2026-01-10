# Optional feature loader (ZSH_FEATURES)
#
# This module is auto-loaded by the bootstrap script group loader and is responsible
# for sourcing any enabled feature init scripts under `scripts/_features/<name>/init.zsh`.
#
# Enable features via a comma-separated list:
#   export ZSH_FEATURES="codex,xxx"
#
# Keep default behavior silent; use `ZSH_DEBUG>=1` for warnings.

typeset features_lib="${ZSH_SCRIPT_DIR-}/_internal/features.zsh"
[[ -r "$features_lib" ]] && source "$features_lib"

if ! (( $+functions[zsh_features::list] )); then
  [[ "${ZSH_DEBUG:-0}" -ge 1 ]] && print -u2 -r -- "features.zsh: missing zsh_features::list (did not load: $features_lib)"
  return 0
fi

typeset features_dir="${ZSH_SCRIPT_DIR-}/_features"
[[ -n "$features_dir" && -d "$features_dir" ]] || return 0

typeset -a enabled_features=()
enabled_features=(${(f)"$(zsh_features::list)"})
(( ${#enabled_features[@]} > 0 )) || return 0

typeset feature='' init_file=''
for feature in "${enabled_features[@]}"; do
  init_file="$features_dir/$feature/init.zsh"
  if [[ -r "$init_file" ]]; then
    if (( $+functions[source_file] )); then
      source_file "$init_file" "feature:$feature"
    else
      source "$init_file"
    fi
  else
    [[ "${ZSH_DEBUG:-0}" -ge 1 ]] && print -u2 -r -- "features.zsh: unknown or missing feature: $feature ($init_file)"
  fi
done

