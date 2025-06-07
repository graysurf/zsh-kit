# Unalias to avoid redefinition warnings
unalias ll lla lt llt lgt lg lgr \
        lt2 lt3 lt5 \
        llt2 llt3 llt5 \
        lgt2 lgt3 lgt5 2>/dev/null

# Basic listings
ll() {
        if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
                eza -alh --icons --group-directories-first --time-style=iso "$@"
        else
                eza -alh --icons --group-directories-first --git-ignore --time-style=iso "$@"
        fi
}
alias lla='eza -alh --icons --group-directories-first --time-style=iso' # Includes .gitignored files

# Tree views (unlimited depth)
alias lt='ll -T'  # Simple tree view
alias llt='ll -T' # Long format tree view
alias lgt='lg -T' # Git-aware tree view

# Git-aware listings
alias lg='eza -alh --icons --group-directories-first --git --time-style=iso'
alias lgr='eza -alh --icons --group-directories-first --git --git-repos --time-style=iso'

# Tree views with depth limits
alias lt2='ll -T -L 2'
alias lt3='ll -T -L 3'
alias lt5='ll -T -L 5'

alias llt2='ll -T -L 2'
alias llt3='ll -T -L 3'
alias llt5='ll -T -L 5'

alias lgt2='lg -T -L 2'
alias lgt3='lg -T -L 3'
alias lgt5='lg -T -L 5'
