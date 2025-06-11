safe_unalias \
        ll lx lt llt lt2 lt3 lt5 \
        llt2 llt3 llt5 \
        lxt lxt2 lxt3 lxt5

# List all files including dotfiles
alias ll='eza -alh --icons --group-directories-first --time-style=iso'
# List all files including dotfiles
alias lx='eza -lh   --icons --group-directories-first --color=always --time-style=iso'

# Tree view with all files
alias lt='eza -aT --group-directories-first --color=always --icons'
# Long-format tree view with all files
alias llt='ll -T'

# Tree views with depth limits
alias lt2='ll -T -L 2'
alias lt3='ll -T -L 3'
alias lt5='ll -T -L 5'

alias llt2='ll -T -L 2'
alias llt3='ll -T -L 3'
alias llt5='ll -T -L 5'

# Tree view excluding dotfiles
alias lxt='lx -T'

# Tree views excluding dotfiles with depth limits
alias lxt2='lx -T -L 2'
alias lxt3='lx -T -L 3'
alias lxt5='lx -T -L 5'



