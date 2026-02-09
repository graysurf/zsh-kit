# nils-cli aliases
#
# Source Homebrew's nils-cli alias bundle when available.
# Keep this interactive-only because aliases are shell UX, not runtime deps.
[[ -o interactive ]] || return 0

typeset nils_cli_aliases=''

if command -v brew >/dev/null 2>&1; then
  typeset nils_cli_prefix=''
  nils_cli_prefix="$(brew --prefix nils-cli 2>/dev/null || true)"
  if [[ -n "$nils_cli_prefix" ]]; then
    nils_cli_aliases="$nils_cli_prefix/share/zsh/site-functions/aliases.zsh"
  fi
fi

if [[ -f "$nils_cli_aliases" ]]; then
  source "$nils_cli_aliases"
fi
