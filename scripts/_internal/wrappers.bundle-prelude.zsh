# Wrapper runtime prelude for bundled cached CLI wrappers.
#
# This file is intended to be *inlined* into generated wrapper binaries under:
#   $ZSH_CACHE_DIR/wrappers/bin/*
#
# It should remain safe to execute (no top-level `return`), and it should not
# depend on any other files at runtime.

# bundle-wrapper.zsh emits `set -e`; disable it to match the previous wrapper behavior.
set +e

typeset wrapper_bin="${0:A:h}"
[[ -d "$wrapper_bin" ]] && export PATH="$wrapper_bin:$PATH"

typeset wrapper_cache_dir="${wrapper_bin:h:h}"
export ZSH_CACHE_DIR="${ZSH_CACHE_DIR:-$wrapper_cache_dir}"
export ZSH_COMPDUMP="${ZSH_COMPDUMP:-$ZSH_CACHE_DIR/.zcompdump}"

[[ -d "$ZSH_CACHE_DIR" ]] || mkdir -p -- "$ZSH_CACHE_DIR"

