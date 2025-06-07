#compdef git-lock

__git_lock_labels() {
  ...
}

_git_lock_completion() {
  _arguments -s -C \
    '1:command:((lock\:Save\ commit\ hash\ to\ lock \
                 unlock\:Reset\ to\ a\ saved\ commit \
                 list\:Show\ all\ locks \
                 copy\:Duplicate\ a\ lock\ label \
                 delete\:Remove\ a\ lock \
                 diff\:Compare\ two\ locks \
                 tag\:Create\ a\ tag\ from\ a\ lock))' \
    '*::args:->args'

  case $words[2] in
    unlock|delete)
      _values 'label' $(__git_lock_labels)
      ;;
    copy)
      if (( CURRENT == 3 )); then
        _values 'source label' $(__git_lock_labels)
      elif (( CURRENT == 4 )); then
        _message 'target label'
      fi
      ;;
    diff)
      if (( CURRENT == 3 || CURRENT == 4 )); then
        _values 'label' $(__git_lock_labels)
      fi
      ;;
    tag)
      if (( CURRENT == 3 )); then
        _values 'glock label' $(__git_lock_labels)
      elif (( CURRENT == 4 )); then
        _message 'git tag name'
      elif [[ $words[CURRENT-1] == "-m" ]]; then
        _message 'tag message'
      fi
      ;;
  esac
}

compdef _git_lock_completion git-lock
