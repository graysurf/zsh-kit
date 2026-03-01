# THIRD_PARTY_LICENSES

This document lists third-party software used by this repository.

## Scope

- First-party code in this repository is licensed under MIT (`LICENSE`).
- Third-party plugin code is fetched from upstream Git repositories defined in `config/plugins.list`.
- The `plugins/` directory is git-ignored, so third-party source is not tracked in this repository.
- This file focuses on plugin dependencies that are automatically loaded by `bootstrap/plugins.zsh`.

## Third-Party Components

| Component | Upstream Repository | License | Evidence |
| --- | --- | --- | --- |
| `fzf-tab` | <https://github.com/Aloxaf/fzf-tab> | MIT | `plugins/fzf-tab/LICENSE` |
| `fast-syntax-highlighting` | <https://github.com/zdharma-continuum/fast-syntax-highlighting> | BSD-3-Clause | `plugins/fast-syntax-highlighting/LICENSE` |
| `zsh-autosuggestions` | <https://github.com/zsh-users/zsh-autosuggestions> | MIT | `plugins/zsh-autosuggestions/LICENSE` |
| `zsh-history-substring-search` | <https://github.com/zsh-users/zsh-history-substring-search> | BSD-3-Clause (documented in README history) | `plugins/zsh-history-substring-search/README.md` (no standalone LICENSE file in local clone) |
| `zsh-direnv` (from `direnv`) | <https://github.com/direnv/direnv> | MIT | `plugins/zsh-direnv/LICENSE` |
| `zsh-abbr` | <https://github.com/olets/zsh-abbr> | Hippocratic License 3.0 + CC BY-NC-SA 4.0 terms | `plugins/zsh-abbr/LICENSE` |

## Notes

- Plugin versions are not pinned in `config/plugins.list`; each plugin is cloned/updated from its upstream repository.
- `zsh-abbr` is not a permissive MIT/BSD-style license. Review its non-commercial and ethical-use terms before distribution or commercial use.
- To refresh this list, verify `config/plugins.list` and each fetched plugin's `LICENSE` (or equivalent) file under `plugins/`.
