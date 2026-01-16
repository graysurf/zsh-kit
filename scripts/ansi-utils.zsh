# ANSI / color helpers (zsh-only).
# Module file: defines functions only; safe to source.

# ansi::should_color [fd]
# Return 0 when ANSI colors should be enabled (TTY + NO_COLOR not set).
ansi::should_color() {
  emulate -L zsh
  setopt localoptions nounset

  local fd="${1-1}"
  [[ "${fd}" == <-> ]] || fd='1'

  if [[ -n "${NO_COLOR-}" ]]; then
    return 1
  fi
  [[ -t "${fd}" ]] || return 1

  return 0
}

# ansi::reset
# Print ANSI reset sequence (no newline).
ansi::reset() {
  emulate -L zsh
  setopt localoptions nounset

  printf '\033[0m'
}

# ansi::fg_truecolor <r> <g> <b>
# Print ANSI 24-bit foreground color escape (no newline).
ansi::fg_truecolor() {
  emulate -L zsh
  setopt localoptions pipe_fail err_return nounset

  local r_raw="${1-}" g_raw="${2-}" b_raw="${3-}"
  [[ -n "${r_raw}" && "${r_raw}" == <-> ]] || return 1
  [[ -n "${g_raw}" && "${g_raw}" == <-> ]] || return 1
  [[ -n "${b_raw}" && "${b_raw}" == <-> ]] || return 1

  local -i r="${r_raw}" g="${g_raw}" b="${b_raw}"
  if (( r < 0 || r > 255 || g < 0 || g > 255 || b < 0 || b > 255 )); then
    return 1
  fi

  printf '\033[38;2;%d;%d;%dm' "${r}" "${g}" "${b}"
}

# ansi::extract_percent
# Extract the numeric percent from strings like "100%" or "5h:100%".
ansi::extract_percent() {
  emulate -L zsh
  setopt localoptions pipe_fail err_return nounset

  local raw="${1-}"
  raw="${raw##*:}"
  raw="${raw%%%}"
  raw="${raw//[[:space:]]/}"

  [[ -n "${raw}" && "${raw}" == <-> ]] || return 1
  print -r -- "${raw}"
}

# ansi_theme_night_owl::fg_for_percent
# Return Night Owl ANSI foreground color for 0-100% (high->low: teal/green -> red).
ansi_theme_night_owl::fg_for_percent() {
  emulate -L zsh
  setopt localoptions pipe_fail err_return nounset

  local percent_raw="${1-}"
  [[ -n "${percent_raw}" && "${percent_raw}" == <-> ]] || return 1

  local -i percent="${percent_raw}"
  if (( percent >= 80 )); then
    ansi::fg_truecolor 127 219 202  # #7fdbca
  elif (( percent >= 60 )); then
    ansi::fg_truecolor 173 219 103  # #addb67
  elif (( percent >= 40 )); then
    ansi::fg_truecolor 236 196 141  # #ecc48d
  elif (( percent >= 20 )); then
    ansi::fg_truecolor 247 140 108  # #f78c6c
  else
    ansi::fg_truecolor 240 113 120  # #f07178
  fi
}

# ansi_theme_night_owl::format_percent_cell
# Right-align and optionally color a percent cell with a fixed width.
# Usage: ansi_theme_night_owl::format_percent_cell <raw_value> [width] [color_enabled]
ansi_theme_night_owl::format_percent_cell() {
  emulate -L zsh
  setopt localoptions pipe_fail err_return nounset

  local raw="${1-}"
  local width="${2-8}"
  local color_enabled="${3-}"

  if [[ -z "${width}" || "${width}" != <-> ]]; then
    width='8'
  fi

  local padded=''
  padded="$(printf "%${width}.${width}s" "${raw}")"

  if [[ -z "${color_enabled}" ]]; then
    if ansi::should_color 1; then
      color_enabled='true'
    else
      color_enabled='false'
    fi
  fi

  if [[ "${color_enabled}" != 'true' ]]; then
    print -r -- "${padded}"
    return 0
  fi

  local percent=''
  percent="$(ansi::extract_percent "${raw}")" || {
    print -r -- "${padded}"
    return 0
  }

  local color=''
  color="$(ansi_theme_night_owl::fg_for_percent "${percent}")" || {
    print -r -- "${padded}"
    return 0
  }

  printf "%s%s" "${color}" "${padded}"
  ansi::reset
  printf "\n"
  return 0
}

# ansi_theme_night_owl::format_percent_token
# Colorize a token containing a percent (no padding; prints a trailing newline).
# Usage: ansi_theme_night_owl::format_percent_token <raw_token> [color_enabled]
ansi_theme_night_owl::format_percent_token() {
  emulate -L zsh
  setopt localoptions pipe_fail err_return nounset

  local raw="${1-}"
  local color_enabled="${2-}"

  local -i width=0
  width="${#raw}"
  if (( width <= 0 )); then
    print -r -- ''
    return 0
  fi

  ansi_theme_night_owl::format_percent_cell "${raw}" "${width}" "${color_enabled}"
}
