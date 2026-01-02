# ──────────────────────────────
# Define Zsh environment paths early (must be first!)
# ──────────────────────────────

typeset -r base_dir="${ZDOTDIR:-$HOME/.config/zsh}"

[[ -r "$base_dir/scripts/_internal/paths.exports.zsh" ]] && \
  source "$base_dir/scripts/_internal/paths.exports.zsh"

[[ -r "$base_dir/scripts/_internal/paths.init.zsh" ]] && \
  source "$base_dir/scripts/_internal/paths.init.zsh"
