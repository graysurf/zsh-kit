# Plugin-specific configuration.

if [[ -o interactive ]] && (( ${+functions[_zsh_highlight]} )); then
  typeset -gi zsh_fsh_paste_active=0
  typeset -gi zsh_fsh_paste_maxlength_set=0
  typeset -g zsh_fsh_paste_maxlength=''

  # zsh_fsh_paste_disable
  # Temporarily disable zsh-syntax-highlighting length limits during paste.
  # Usage: zsh_fsh_paste_disable
  # Notes:
  # - Saves and later restores `ZSH_HIGHLIGHT_MAXLENGTH`.
  zsh_fsh_paste_disable() {
    emulate -L zsh

    if (( zsh_fsh_paste_active )); then
      return 0
    fi

    if (( ${+ZSH_HIGHLIGHT_MAXLENGTH} )); then
      zsh_fsh_paste_maxlength_set=1
      zsh_fsh_paste_maxlength="${ZSH_HIGHLIGHT_MAXLENGTH}"
    else
      zsh_fsh_paste_maxlength_set=0
      zsh_fsh_paste_maxlength=''
    fi

    zsh_fsh_paste_active=1
    typeset -g ZSH_HIGHLIGHT_MAXLENGTH=0
    region_highlight=()
  }

  # zsh_fsh_paste_restore
  # Restore zsh-syntax-highlighting length limits after paste-related hooks.
  # Usage: zsh_fsh_paste_restore
  zsh_fsh_paste_restore() {
    emulate -L zsh

    if (( ! zsh_fsh_paste_active )); then
      return 0
    fi

    if (( zsh_fsh_paste_maxlength_set )); then
      typeset -g ZSH_HIGHLIGHT_MAXLENGTH="${zsh_fsh_paste_maxlength}"
    else
      unset ZSH_HIGHLIGHT_MAXLENGTH
    fi

    zsh_fsh_paste_active=0
  }

  # zsh_fsh_paste_bracketed
  # ZLE widget wrapper: disable highlighting limits, then run the original paste widget.
  # Usage: zsh_fsh_paste_bracketed [args...]
  zsh_fsh_paste_bracketed() {
    emulate -L zsh
    zsh_fsh_paste_disable
    zle .bracketed-paste -- "$@"
  }

  # zsh_fsh_paste_line_finish
  # ZLE hook: restore highlighting limits when the line is accepted.
  # Usage: zsh_fsh_paste_line_finish
  zsh_fsh_paste_line_finish() {
    emulate -L zsh
    zsh_fsh_paste_restore
  }

  # zsh_fsh_paste_line_init
  # ZLE hook: ensure highlighting limits are restored at line init.
  # Usage: zsh_fsh_paste_line_init
  zsh_fsh_paste_line_init() {
    emulate -L zsh
    zsh_fsh_paste_restore
  }

  # zsh_fsh_paste_pre_redraw
  # ZLE hook: restore highlighting limits before redraw when the buffer becomes empty.
  # Usage: zsh_fsh_paste_pre_redraw
  zsh_fsh_paste_pre_redraw() {
    emulate -L zsh

    if (( zsh_fsh_paste_active )) && [[ -z ${BUFFER-} ]]; then
      zsh_fsh_paste_restore
    fi
  }

  if zmodload zsh/zleparameter 2>/dev/null; then
    if (( $+widgets[bracketed-paste] )); then
      zle -N bracketed-paste zsh_fsh_paste_bracketed
    fi
  fi

  autoload -Uz add-zle-hook-widget
  add-zle-hook-widget line-init zsh_fsh_paste_line_init
  add-zle-hook-widget line-finish zsh_fsh_paste_line_finish
  add-zle-hook-widget line-pre-redraw zsh_fsh_paste_pre_redraw
fi
