# progress_bar::init
# Initialize a determinate progress bar state.
# Usage: progress_bar::init <id> --prefix <text> --total <n> [--width <n>] [--head-len <n>] [--fd <n>] [--enabled|--disabled]
#
# progress_bar::update
# Update a determinate progress bar line (renders to stderr by default when TTY).
# Usage: progress_bar::update <id> <current> [--suffix <text>] [--force]
#
# progress_bar::finish
# Finish a determinate progress bar (forces final render and prints a newline).
# Usage: progress_bar::finish <id> [--suffix <text>]
#
# progress_bar::init_indeterminate
# Initialize an indeterminate progress bar state (ping-pong fill).
# Usage: progress_bar::init_indeterminate <id> --prefix <text> [--width <n>] [--head-len <n>] [--fd <n>] [--enabled|--disabled]
#
# progress_bar::tick
# Advance an indeterminate progress bar animation frame.
# Usage: progress_bar::tick <id> [--suffix <text>] [--force]
#
# progress_bar::stop
# Clear an indeterminate progress bar line and print a newline.
# Usage: progress_bar::stop <id>

(( ${+functions[_progress_bar::build_bar]} )) && return 0
typeset -g _ZSH_PROGRESS_BAR_LOADED=1

typeset -gA _progress_bar_state=()

# _progress_bar::is_utf8_locale
# Return 0 when locale hints UTF-8 support.
_progress_bar::is_utf8_locale() {
  emulate -L zsh

  typeset locale_raw=''
  if [[ -n "${LC_ALL-}" ]]; then
    locale_raw="${LC_ALL-}"
  elif [[ -n "${LC_CTYPE-}" ]]; then
    locale_raw="${LC_CTYPE-}"
  else
    locale_raw="${LANG-}"
  fi

  locale_raw="${locale_raw:u}"
  [[ -n "$locale_raw" && "$locale_raw" == *"UTF-8"* ]] && return 0
  [[ -n "$locale_raw" && "$locale_raw" == *"UTF8"* ]] && return 0
  return 1
}

# _progress_bar::blocks
# Print "full<TAB>mid<TAB>light" (unicode by default; ASCII fallback).
_progress_bar::blocks() {
  emulate -L zsh

  if _progress_bar::is_utf8_locale; then
    print -r -- $'▓\t▒\t░'
    return 0
  fi

  print -r -- $'#\t=\t-'
  return 0
}

# _progress_bar::columns
# Print terminal columns (best-effort).
_progress_bar::columns() {
  emulate -L zsh

  typeset cols_raw="${COLUMNS-}"
  if [[ -n "$cols_raw" && "$cols_raw" == <-> ]]; then
    print -r -- "$cols_raw"
    return 0
  fi

  print -r -- '80'
  return 0
}

# _progress_bar::default_width
# Print default bar width: max(10, cols/4).
_progress_bar::default_width() {
  emulate -L zsh

  typeset cols_raw=''
  cols_raw="$(_progress_bar::columns 2>/dev/null)" || cols_raw='80'
  [[ -n "$cols_raw" && "$cols_raw" == <-> ]] || cols_raw='80'

  typeset -i cols=80 width=20
  cols="$cols_raw"
  (( cols <= 0 )) && cols=80
  width=$(( cols / 4 ))
  (( width < 10 )) && width=10

  print -r -- "$width"
  return 0
}

# _progress_bar::build_bar <filled> <total> <head_len> <full> <mid> <light>
_progress_bar::build_bar() {
  emulate -L zsh

  typeset filled_raw="${1-}" total_raw="${2-}" head_len_raw="${3-}"
  typeset full_block="${4-}" mid_block="${5-}" light_block="${6-}"

  typeset -i filled=0 total=0 head_len=2 head=0 empty=0
  [[ -n "$filled_raw" && "$filled_raw" == <-> ]] && filled="$filled_raw"
  [[ -n "$total_raw" && "$total_raw" == <-> ]] && total="$total_raw"
  [[ -n "$head_len_raw" && "$head_len_raw" == <-> ]] && head_len="$head_len_raw"

  (( total < 0 )) && total=0
  (( filled < 0 )) && filled=0
  (( filled > total )) && filled=total
  (( head_len < 0 )) && head_len=0

  head=$(( total - filled ))
  (( head < 0 )) && head=0
  (( head > head_len )) && head=head_len

  empty=$(( total - filled - head ))
  (( empty < 0 )) && empty=0

  typeset bar=''
  repeat "$filled" bar+="$full_block"
  repeat "$head" bar+="$mid_block"
  repeat "$empty" bar+="$light_block"

  print -r -- "$bar"
  return 0
}

# _progress_bar::key <id> <field>
_progress_bar::key() {
  emulate -L zsh
  print -r -- "${1-},${2-}"
}

# _progress_bar::enabled_for_fd <fd>
_progress_bar::enabled_for_fd() {
  emulate -L zsh
  typeset fd_raw="${1-2}"
  [[ -n "$fd_raw" && "$fd_raw" == <-> ]] || fd_raw='2'
  [[ -t "$fd_raw" ]] && return 0
  return 1
}

# _progress_bar::write_line <id> <fd> <line>
_progress_bar::write_line() {
  emulate -L zsh

  typeset id="${1-}" fd_raw="${2-2}" line="${3-}"
  [[ -n "$id" ]] || return 0
  [[ -n "$fd_raw" && "$fd_raw" == <-> ]] || fd_raw='2'

  typeset cols_raw=''
  cols_raw="$(_progress_bar::columns 2>/dev/null)" || cols_raw='80'
  [[ -n "$cols_raw" && "$cols_raw" == <-> ]] || cols_raw='80'
  typeset -i cols=80 max_len=79
  cols="$cols_raw"
  (( cols <= 0 )) && cols=80
  max_len=$(( cols - 1 ))
  (( max_len < 10 )) && max_len=10

  typeset last_len_key=''
  last_len_key="$(_progress_bar::key "$id" last_len)"
  typeset -i last_len=0 line_len=0
  last_len="${_progress_bar_state[$last_len_key]:-0}"
  if (( ${#line} > max_len )); then
    line="${line[1,${max_len}]}"
  fi
  line_len="${#line}"

  typeset padded="$line"
  if (( last_len > line_len )); then
    padded="${(r:${last_len}:: :)line}"
  fi

  print -u"$fd_raw" -n -r -- $'\r'
  print -u"$fd_raw" -n -r -- "$padded"

  _progress_bar_state[$last_len_key]="$line_len"
  return 0
}

# _progress_bar::clear_line <id> <fd>
_progress_bar::clear_line() {
  emulate -L zsh

  typeset id="${1-}" fd_raw="${2-2}"
  [[ -n "$id" ]] || return 0
  [[ -n "$fd_raw" && "$fd_raw" == <-> ]] || fd_raw='2'

  typeset last_len_key=''
  last_len_key="$(_progress_bar::key "$id" last_len)"
  typeset -i last_len=0
  last_len="${_progress_bar_state[$last_len_key]:-0}"
  (( last_len <= 0 )) && return 0

  print -u"$fd_raw" -n -r -- $'\r'
  print -u"$fd_raw" -n -r -- "${(l:${last_len}:: :)""}"
  print -u"$fd_raw" -n -r -- $'\r'

  _progress_bar_state[$last_len_key]='0'
  return 0
}

# _progress_bar::unset_id <id>
_progress_bar::unset_id() {
  emulate -L zsh

  typeset id="${1-}"
  [[ -n "$id" ]] || return 0

  typeset field=''
  for field in \
    mode prefix total width head_len fd enabled last_len last_filled pos dir; do
    unset "_progress_bar_state[${id},${field}]" 2>/dev/null || true
  done
  return 0
}

# progress_bar::init <id> --prefix <text> --total <n> [...]
progress_bar::init() {
  emulate -L zsh
  setopt localoptions pipe_fail

  typeset id="${1-}"
  shift || true

  if [[ -z "$id" || "$id" == *','* ]]; then
    print -u2 -r -- "progress_bar::init: invalid id (must be non-empty and must not include ','): ${id-}"
    return 2
  fi

  if ! zmodload zsh/zutil 2>/dev/null; then
    print -u2 -r -- "progress_bar::init: zsh/zutil is required for option parsing"
    return 1
  fi

  typeset -A opts=()
  zparseopts -D -E -A opts -- \
    -prefix: \
    -total: \
    -width: \
    -head-len: \
    -fd: \
    -enabled -disabled

  typeset prefix="${opts[--prefix]-}"
  typeset total_raw="${opts[--total]-}"
  typeset width_raw="${opts[--width]-}"
  typeset head_len_raw="${opts[--head-len]-}"
  typeset fd_raw="${opts[--fd]-}"

  if [[ -z "$prefix" || -z "$total_raw" || "$total_raw" != <-> ]]; then
    print -u2 -r -- "progress_bar::init: usage: progress_bar::init <id> --prefix <text> --total <n> [--width <n>] [--head-len <n>] [--fd <n>] [--enabled|--disabled]"
    return 2
  fi

  typeset -i total=0 width=0 head_len=0 fd=0
  total="$total_raw"
  (( total < 0 )) && total=0

  width=0
  if [[ -n "$width_raw" && "$width_raw" == <-> ]]; then
    width="$width_raw"
  fi
  if (( width <= 0 )); then
    width="$(_progress_bar::default_width 2>/dev/null)" || width=10
  fi
  (( width < 10 )) && width=10

  head_len=2
  if [[ -n "$head_len_raw" && "$head_len_raw" == <-> ]]; then
    head_len="$head_len_raw"
  fi
  (( head_len < 0 )) && head_len=0

  fd=2
  if [[ -n "$fd_raw" && "$fd_raw" == <-> ]]; then
    fd="$fd_raw"
  fi

  typeset enabled='auto'
  if (( ${+opts[--enabled]} )); then
    enabled='true'
  elif (( ${+opts[--disabled]} )); then
    enabled='false'
  fi

  if [[ "$enabled" == 'auto' ]]; then
    if _progress_bar::enabled_for_fd "$fd"; then
      enabled='true'
    else
      enabled='false'
    fi
  fi

  _progress_bar_state[${id},mode]='determinate'
  _progress_bar_state[${id},prefix]="$prefix"
  _progress_bar_state[${id},total]="$total"
  _progress_bar_state[${id},width]="$width"
  _progress_bar_state[${id},head_len]="$head_len"
  _progress_bar_state[${id},fd]="$fd"
  _progress_bar_state[${id},enabled]="$enabled"
  _progress_bar_state[${id},last_len]='0'
  _progress_bar_state[${id},last_filled]='-1'

  return 0
}

# progress_bar::update <id> <current> [--suffix <text>] [--force]
progress_bar::update() {
  emulate -L zsh
  setopt localoptions pipe_fail

  typeset id="${1-}"
  typeset current_raw="${2-}"
  shift 2 || true

  if [[ -z "$id" || "$id" == *','* ]]; then
    print -u2 -r -- "progress_bar::update: invalid id: ${id-}"
    return 2
  fi

  if [[ "${_progress_bar_state[${id},mode]-}" != 'determinate' ]]; then
    print -u2 -r -- "progress_bar::update: unknown id (did you call progress_bar::init?): $id"
    return 2
  fi

  if [[ "${_progress_bar_state[${id},enabled]-false}" != 'true' ]]; then
    return 0
  fi

  if ! zmodload zsh/zutil 2>/dev/null; then
    return 0
  fi

  typeset -A opts=()
  zparseopts -D -E -A opts -- -suffix: -force
  typeset suffix="${opts[--suffix]-}"
  typeset force='false'
  (( ${+opts[--force]} )) && force='true'

  if [[ -z "$current_raw" || "$current_raw" != <-> ]]; then
    print -u2 -r -- "progress_bar::update: usage: progress_bar::update <id> <current> [--suffix <text>] [--force]"
    return 2
  fi

  typeset prefix="${_progress_bar_state[${id},prefix]-}"
  typeset total_raw="${_progress_bar_state[${id},total]-0}"
  typeset width_raw="${_progress_bar_state[${id},width]-10}"
  typeset head_len_raw="${_progress_bar_state[${id},head_len]-2}"
  typeset fd_raw="${_progress_bar_state[${id},fd]-2}"
  typeset last_filled_raw="${_progress_bar_state[${id},last_filled]--1}"

  typeset -i current_int=0 total=0 width=0 head_len=0 fd=0 filled=0 last_filled=0
  current_int="$current_raw"
  total="$total_raw"
  width="$width_raw"
  head_len="$head_len_raw"
  fd="$fd_raw"
  last_filled="$last_filled_raw"

  (( total < 0 )) && total=0
  (( current_int < 0 )) && current_int=0
  if (( total > 0 && current_int > total )); then
    current_int=total
  fi

  filled=$(( total <= 0 ? 0 : (width * current_int / total) ))
  (( filled < 0 )) && filled=0
  (( filled > width )) && filled=width

  if [[ "$force" != 'true' ]]; then
    if ! (( current_int == 0 || (total > 0 && current_int == total) || filled != last_filled )); then
      return 0
    fi
  fi

  typeset blocks=''
  blocks="$(_progress_bar::blocks 2>/dev/null)" || blocks=$'▓\t▒\t░'
  typeset full_block="${blocks%%$'\t'*}"
  typeset rest="${blocks#*$'\t'}"
  typeset mid_block="${rest%%$'\t'*}"
  typeset light_block="${rest#*$'\t'}"

  typeset bar=''
  bar="$(_progress_bar::build_bar "$filled" "$width" "$head_len" "$full_block" "$mid_block" "$light_block" 2>/dev/null)" || bar=''

  typeset line="${prefix} [${bar}] ${current_int}/${total}"
  [[ -n "$suffix" ]] && line="${line} ${suffix}"

  _progress_bar::write_line "$id" "$fd" "$line" || true
  _progress_bar_state[${id},last_filled]="$filled"
  return 0
}

# progress_bar::finish <id> [--suffix <text>]
progress_bar::finish() {
  emulate -L zsh
  setopt localoptions pipe_fail

  typeset id="${1-}"
  shift || true

  if [[ -z "$id" || "$id" == *','* ]]; then
    print -u2 -r -- "progress_bar::finish: invalid id: ${id-}"
    return 2
  fi

  if [[ "${_progress_bar_state[${id},mode]-}" != 'determinate' ]]; then
    return 0
  fi

  typeset fd_raw="${_progress_bar_state[${id},fd]-2}"
  typeset fd='2'
  [[ -n "$fd_raw" && "$fd_raw" == <-> ]] && fd="$fd_raw"

  if [[ "${_progress_bar_state[${id},enabled]-false}" == 'true' ]]; then
    typeset total_raw="${_progress_bar_state[${id},total]-0}"
    [[ -n "$total_raw" && "$total_raw" == <-> ]] || total_raw='0'
    progress_bar::update "$id" "$total_raw" --force "$@"
    print -u"$fd" -r -- ''
  fi

  _progress_bar::unset_id "$id" || true
  return 0
}

# progress_bar::init_indeterminate <id> --prefix <text> [...]
progress_bar::init_indeterminate() {
  emulate -L zsh
  setopt localoptions pipe_fail

  typeset id="${1-}"
  shift || true

  if [[ -z "$id" || "$id" == *','* ]]; then
    print -u2 -r -- "progress_bar::init_indeterminate: invalid id (must be non-empty and must not include ','): ${id-}"
    return 2
  fi

  if ! zmodload zsh/zutil 2>/dev/null; then
    print -u2 -r -- "progress_bar::init_indeterminate: zsh/zutil is required for option parsing"
    return 1
  fi

  typeset -A opts=()
  zparseopts -D -E -A opts -- \
    -prefix: \
    -width: \
    -head-len: \
    -fd: \
    -enabled -disabled

  typeset prefix="${opts[--prefix]-}"
  typeset width_raw="${opts[--width]-}"
  typeset head_len_raw="${opts[--head-len]-}"
  typeset fd_raw="${opts[--fd]-}"

  if [[ -z "$prefix" ]]; then
    print -u2 -r -- "progress_bar::init_indeterminate: usage: progress_bar::init_indeterminate <id> --prefix <text> [--width <n>] [--head-len <n>] [--fd <n>] [--enabled|--disabled]"
    return 2
  fi

  typeset -i width=0 head_len=0 fd=0
  width=0
  if [[ -n "$width_raw" && "$width_raw" == <-> ]]; then
    width="$width_raw"
  fi
  if (( width <= 0 )); then
    width="$(_progress_bar::default_width 2>/dev/null)" || width=10
  fi
  (( width < 10 )) && width=10

  head_len=2
  if [[ -n "$head_len_raw" && "$head_len_raw" == <-> ]]; then
    head_len="$head_len_raw"
  fi
  (( head_len < 0 )) && head_len=0

  fd=2
  if [[ -n "$fd_raw" && "$fd_raw" == <-> ]]; then
    fd="$fd_raw"
  fi

  typeset enabled='auto'
  if (( ${+opts[--enabled]} )); then
    enabled='true'
  elif (( ${+opts[--disabled]} )); then
    enabled='false'
  fi

  if [[ "$enabled" == 'auto' ]]; then
    if _progress_bar::enabled_for_fd "$fd"; then
      enabled='true'
    else
      enabled='false'
    fi
  fi

  _progress_bar_state[${id},mode]='indeterminate'
  _progress_bar_state[${id},prefix]="$prefix"
  _progress_bar_state[${id},total]='0'
  _progress_bar_state[${id},width]="$width"
  _progress_bar_state[${id},head_len]="$head_len"
  _progress_bar_state[${id},fd]="$fd"
  _progress_bar_state[${id},enabled]="$enabled"
  _progress_bar_state[${id},last_len]='0'
  _progress_bar_state[${id},last_filled]='-1'
  _progress_bar_state[${id},pos]='0'
  _progress_bar_state[${id},dir]='1'

  return 0
}

# progress_bar::tick <id> [--suffix <text>] [--force]
progress_bar::tick() {
  emulate -L zsh
  setopt localoptions pipe_fail

  typeset id="${1-}"
  shift || true

  if [[ -z "$id" || "$id" == *','* ]]; then
    print -u2 -r -- "progress_bar::tick: invalid id: ${id-}"
    return 2
  fi

  if [[ "${_progress_bar_state[${id},mode]-}" != 'indeterminate' ]]; then
    print -u2 -r -- "progress_bar::tick: unknown id (did you call progress_bar::init_indeterminate?): $id"
    return 2
  fi

  if [[ "${_progress_bar_state[${id},enabled]-false}" != 'true' ]]; then
    return 0
  fi

  if ! zmodload zsh/zutil 2>/dev/null; then
    return 0
  fi

  typeset -A opts=()
  zparseopts -D -E -A opts -- -suffix: -force
  typeset suffix="${opts[--suffix]-}"
  typeset force='false'
  (( ${+opts[--force]} )) && force='true'

  typeset prefix="${_progress_bar_state[${id},prefix]-}"
  typeset width_raw="${_progress_bar_state[${id},width]-10}"
  typeset head_len_raw="${_progress_bar_state[${id},head_len]-2}"
  typeset fd_raw="${_progress_bar_state[${id},fd]-2}"
  typeset pos_raw="${_progress_bar_state[${id},pos]-0}"
  typeset dir_raw="${_progress_bar_state[${id},dir]-1}"
  typeset last_filled_raw="${_progress_bar_state[${id},last_filled]--1}"

  typeset -i width=0 head_len=0 fd=0 pos=0 dir=0 filled=0 last_filled=0
  width="$width_raw"
  head_len="$head_len_raw"
  fd="$fd_raw"
  pos="$pos_raw"
  dir="$dir_raw"
  last_filled="$last_filled_raw"

  (( width < 10 )) && width=10
  (( head_len < 0 )) && head_len=0

  if (( dir >= 0 )); then
    dir=1
    pos=$(( pos + 1 ))
    if (( pos >= width )); then
      pos=width
      dir=-1
    fi
  else
    dir=-1
    pos=$(( pos - 1 ))
    if (( pos <= 0 )); then
      pos=0
      dir=1
    fi
  fi

  filled="$pos"
  if [[ "$force" != 'true' ]]; then
    if ! (( filled != last_filled || filled == 0 || filled == width )); then
      _progress_bar_state[${id},pos]="$pos"
      _progress_bar_state[${id},dir]="$dir"
      return 0
    fi
  fi

  typeset blocks=''
  blocks="$(_progress_bar::blocks 2>/dev/null)" || blocks=$'▓\t▒\t░'
  typeset full_block="${blocks%%$'\t'*}"
  typeset rest="${blocks#*$'\t'}"
  typeset mid_block="${rest%%$'\t'*}"
  typeset light_block="${rest#*$'\t'}"

  typeset bar=''
  bar="$(_progress_bar::build_bar "$filled" "$width" "$head_len" "$full_block" "$mid_block" "$light_block" 2>/dev/null)" || bar=''

  typeset line="${prefix} [${bar}]"
  [[ -n "$suffix" ]] && line="${line} ${suffix}"

  _progress_bar::write_line "$id" "$fd" "$line" || true

  _progress_bar_state[${id},pos]="$pos"
  _progress_bar_state[${id},dir]="$dir"
  _progress_bar_state[${id},last_filled]="$filled"

  return 0
}

# progress_bar::stop <id>
progress_bar::stop() {
  emulate -L zsh
  setopt localoptions pipe_fail

  typeset id="${1-}"
  if [[ -z "$id" || "$id" == *','* ]]; then
    print -u2 -r -- "progress_bar::stop: invalid id: ${id-}"
    return 2
  fi

  typeset fd_raw="${_progress_bar_state[${id},fd]-2}"
  typeset fd='2'
  [[ -n "$fd_raw" && "$fd_raw" == <-> ]] && fd="$fd_raw"

  if [[ "${_progress_bar_state[${id},enabled]-false}" == 'true' ]]; then
    _progress_bar::clear_line "$id" "$fd" || true
    print -u"$fd" -r -- ''
  fi

  _progress_bar::unset_id "$id" || true
  return 0
}
