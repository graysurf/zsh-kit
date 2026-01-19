# Optional feature loader (ZSH_FEATURES)
#
# This module is auto-loaded by the bootstrap script group loader and is responsible
# for sourcing any enabled feature init scripts under `scripts/_features/<name>/init.zsh`.
#
# Enable features via a comma-separated list:
#   export ZSH_FEATURES="codex,xxx"
#
# Keep default behavior silent; use `ZSH_DEBUG>=2` for warnings.

typeset features_lib="${ZSH_SCRIPT_DIR-}/_internal/features.zsh"
[[ -r "$features_lib" ]] && source "$features_lib"

typeset features_dir="${ZSH_SCRIPT_DIR-}/_features"
typeset -a enabled_features=() loaded_features=() missing_features=() failed_features=()

typeset -ga ZSH_FEATURES_LOADED=() ZSH_FEATURES_MISSING=() ZSH_FEATURES_FAILED=()

if (( $+functions[zsh_features::list] )); then
  enabled_features=(${(f)"$(zsh_features::list)"})
else
  [[ "${ZSH_DEBUG:-0}" -ge 2 ]] && print -u2 -r -- "features.zsh: missing zsh_features::list (did not load: $features_lib)"
fi

if [[ -n "$features_dir" && -d "$features_dir" && ${#enabled_features[@]} -gt 0 ]]; then
  typeset feature='' init_file='' rc=0
  for feature in "${enabled_features[@]}"; do
    init_file="$features_dir/$feature/init.zsh"
    if [[ -r "$init_file" ]]; then
      if (( $+functions[source_file] )); then
        source_file "$init_file" "feature:$feature"
        rc=$?
      else
        source "$init_file"
        rc=$?
      fi

      if (( rc == 0 )); then
        loaded_features+=("$feature")
      else
        failed_features+=("$feature")
      fi
    else
      missing_features+=("$feature")
      [[ "${ZSH_DEBUG:-0}" -ge 2 ]] && print -u2 -r -- "features.zsh: unknown or missing feature: $feature ($init_file)"
    fi
  done
fi

ZSH_FEATURES_LOADED=("${loaded_features[@]}")
ZSH_FEATURES_MISSING=("${missing_features[@]}")
ZSH_FEATURES_FAILED=("${failed_features[@]}")
