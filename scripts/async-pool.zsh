(( ${+functions[async_pool::map]} )) && return 0
typeset -g _ZSH_ASYNC_POOL_LOADED=1

# async_pool::map
# Run a worker function concurrently across items and update a determinate progress bar.
# Usage: async_pool::map --worker <fn> [--jobs <n>] [--prefix <text>] [--fd <n>] [--enabled|--disabled] [--debug] -- <item...>
#
# Worker contract:
# - Called as: <fn> <item>
# - stdout: single-line result (newlines/tabs are normalized to spaces)
# - stderr: captured per item (printed after completion with --debug)
# - exit code: propagated per item; async_pool::map returns non-zero when any item failed
async_pool::map() {
  emulate -L zsh
  setopt localoptions pipe_fail nounset
  setopt localtraps
  builtin unsetopt monitor notify

  if ! zmodload zsh/zutil 2>/dev/null; then
    print -ru2 -r -- "async_pool::map: zsh/zutil is required for option parsing"
    return 1
  fi

  local jobs_raw="${ASYNC_POOL_JOBS:-10}"
  local prefix='async-pool'
  local worker=''
  local debug_mode='false'
  local fd_raw='2'
  local enabled_mode='auto'

  local -A opts=()
  zparseopts -D -E -A opts -- \
    -jobs: \
    -prefix: \
    -worker: \
    -fd: \
    -enabled -disabled \
    -debug

  if [[ "${1-}" == '--' ]]; then
    shift
  fi

  if [[ -n "${opts[--jobs]-}" ]]; then
    jobs_raw="${opts[--jobs]}"
  fi
  if [[ -n "${opts[--prefix]-}" ]]; then
    prefix="${opts[--prefix]}"
  fi
  if [[ -n "${opts[--worker]-}" ]]; then
    worker="${opts[--worker]}"
  fi
  if [[ -n "${opts[--fd]-}" ]]; then
    fd_raw="${opts[--fd]}"
  fi
  if (( ${+opts[--debug]} )); then
    debug_mode='true'
  fi
  if (( ${+opts[--enabled]} )); then
    enabled_mode='true'
  elif (( ${+opts[--disabled]} )); then
    enabled_mode='false'
  fi

  if [[ -z "${worker}" || $# -eq 0 ]]; then
    print -ru2 -r -- "async_pool::map: usage: async_pool::map --worker <fn> [--jobs <n>] [--prefix <text>] [--fd <n>] [--enabled|--disabled] [--debug] -- <item...>"
    return 64
  fi

  if ! typeset -f "${worker}" >/dev/null 2>&1; then
    print -ru2 -r -- "async_pool::map: worker function not found: ${worker}"
    return 1
  fi

  if [[ -z "${jobs_raw}" || "${jobs_raw}" != <-> ]]; then
    jobs_raw='10'
  fi
  local -i jobs="${jobs_raw}"
  if (( jobs <= 0 )); then
    jobs=10
  fi

  if [[ -z "${fd_raw}" || "${fd_raw}" != <-> ]]; then
    fd_raw='2'
  fi
  local -i fd="${fd_raw}"
  if (( fd <= 0 )); then
    fd=2
  fi

  local -a items=()
  items=("$@")
  local -i total="${#items[@]}"

  local tmp_dir=''
  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/async-pool.XXXXXX" 2>/dev/null)" || tmp_dir=''
  if [[ -z "${tmp_dir}" || ! -d "${tmp_dir}" ]]; then
    print -ru2 -r -- "async_pool::map: failed to create temp dir"
    return 1
  fi

  local fifo="${tmp_dir}/events.fifo"
  if ! mkfifo -- "${fifo}" 2>/dev/null; then
    print -ru2 -r -- "async_pool::map: failed to create fifo: ${fifo}"
    command rm -rf -- "${tmp_dir}" 2>/dev/null || true
    return 1
  fi

  exec 9<> "${fifo}" || {
    print -ru2 -r -- "async_pool::map: failed to open fifo: ${fifo}"
    command rm -rf -- "${tmp_dir}" 2>/dev/null || true
    return 1
  }

  trap "exec 9>&- 2>/dev/null || true; command rm -rf -- ${(qq)tmp_dir} 2>/dev/null || true" EXIT

  local progress_id='' progress_active='false'
  progress_id="async-pool:${$}"
  progress_active='false'
  if (( $+functions[progress_bar::init] )); then
    local -a pb_args=()
    pb_args=( --prefix "${prefix}" --total "${total}" --fd "${fd}" )
    if [[ "${enabled_mode}" == 'true' ]]; then
      pb_args+=( --enabled )
    elif [[ "${enabled_mode}" == 'false' ]]; then
      pb_args+=( --disabled )
    fi

    progress_active='true'
    progress_bar::init "$progress_id" "${pb_args[@]}" || progress_active='false'
    if [[ "$progress_active" == 'true' ]]; then
      progress_bar::update "$progress_id" 0 --suffix 'starting...' --force || true
    fi
  fi

  local -A stderr_files=()
  local -A result_lines=()
  local -A result_rcs=()

  local -i next_index=1 running=0 completed=0 overall_rc=0
  local index_raw='' pid='' event_index='' event_pid='' event_rc='' event_line=''
  local err_file='' item='' tab=$'\t'

  while (( running < jobs && next_index <= total )); do
    index_raw="${next_index}"
    item="${items[$next_index]}"
    err_file="${tmp_dir}/err.${index_raw}.log"
    stderr_files[$index_raw]="${err_file}"

    () {
      emulate -L zsh
      setopt localoptions pipe_fail nounset
      setopt localtraps

      local index_raw="${1-}"
      local item="${2-}"
      local worker="${3-}"
      local err_file="${4-}"

      local out='' child_rc=0 tab=$'\t'
      if out="$("${worker}" "${item}" 2>"${err_file}")"; then
        child_rc=0
      else
        child_rc=$?
      fi

      out="${out//$'\n'/ }"
      out="${out//$'\r'/ }"
      out="${out//$'\t'/ }"

      print -u9 -r -- "${index_raw}${tab}${$}${tab}${child_rc}${tab}${out}"
      return 0
    } "${index_raw}" "${item}" "${worker}" "${err_file}" &

    running=$(( running + 1 ))
    next_index=$(( next_index + 1 ))
  done

  while (( completed < total )); do
    if ! IFS=$'\t' read -r -u 9 event_index event_pid event_rc event_line; then
      overall_rc=1
      break
    fi

    completed=$(( completed + 1 ))
    running=$(( running - 1 ))

    result_lines[$event_index]="${event_line}"
    result_rcs[$event_index]="${event_rc}"

    if [[ -z "${event_rc}" || "${event_rc}" != <-> ]]; then
      overall_rc=1
    elif (( event_rc != 0 )); then
      overall_rc=1
    fi

    if [[ "$progress_active" == 'true' ]]; then
      item="${items[$event_index]}"
      progress_bar::update "$progress_id" "$completed" --suffix "${item}" --force || true
    fi

    if [[ -n "${event_pid}" && "${event_pid}" == <-> ]]; then
      wait "${event_pid}" 2>/dev/null || true
    fi

    while (( running < jobs && next_index <= total )); do
      index_raw="${next_index}"
      item="${items[$next_index]}"
      err_file="${tmp_dir}/err.${index_raw}.log"
      stderr_files[$index_raw]="${err_file}"

      () {
        emulate -L zsh
        setopt localoptions pipe_fail nounset
        setopt localtraps

        local index_raw="${1-}"
        local item="${2-}"
        local worker="${3-}"
        local err_file="${4-}"

        local out='' child_rc=0 tab=$'\t'
        if out="$("${worker}" "${item}" 2>"${err_file}")"; then
          child_rc=0
        else
          child_rc=$?
        fi

        out="${out//$'\n'/ }"
        out="${out//$'\r'/ }"
        out="${out//$'\t'/ }"

        print -u9 -r -- "${index_raw}${tab}${$}${tab}${child_rc}${tab}${out}"
        return 0
      } "${index_raw}" "${item}" "${worker}" "${err_file}" &

      running=$(( running + 1 ))
      next_index=$(( next_index + 1 ))
    done
  done

  if [[ "$progress_active" == 'true' ]]; then
    progress_bar::finish "$progress_id" --suffix 'done' || true
    progress_active='false'
  fi

  local -i i=0
  for (( i = 1; i <= total; i++ )); do
    item="${items[$i]}"
    event_rc="${result_rcs[$i]-1}"
    event_line="${result_lines[$i]-}"
    print -r -- "${item}${tab}${event_rc}${tab}${event_line}"
  done

  if [[ "${debug_mode}" == 'true' ]]; then
    local printed='false' path='' rc_raw=''
    for (( i = 1; i <= total; i++ )); do
      path="${stderr_files[$i]-}"
      [[ -n "${path}" && -s "${path}" ]] || continue

      if [[ "${printed}" != 'true' ]]; then
        printed='true'
        print -ru2 -r -- ''
        print -ru2 -r -- 'async_pool::map: per-item stderr (captured):'
      fi
      print -ru2 -r -- "---- ${items[$i]} ----"
      cat -- "${path}" 1>&2
    done
  fi

  return "${overall_rc}"
}

# async_pool_demo::_sleep_worker
# Demo worker: sleep 1–5 seconds and print "slept=<Ns>".
async_pool_demo::_sleep_worker() {
  emulate -L zsh
  setopt localoptions pipe_fail nounset

  local item="${1-}"
  [[ -n "${item}" ]] || return 64

  local -i seconds=$(( (RANDOM % 5) + 1 ))
  sleep "${seconds}"
  print -r -- "slept=${seconds}s"
  return 0
}

# async_pool_demo::sleep
# Demo: run N tasks concurrently; each task sleeps 1–5 seconds.
# Usage: async_pool_demo::sleep [--count <n>] [--jobs <n>] [--prefix <text>] [--debug] [--enabled|--disabled]
async_pool_demo::sleep() {
  emulate -L zsh
  setopt localoptions pipe_fail nounset

  if ! zmodload zsh/zutil 2>/dev/null; then
    print -ru2 -r -- "async_pool_demo::sleep: zsh/zutil is required for option parsing"
    return 1
  fi

  local count_raw='10'
  local jobs_raw='10'
  local prefix='sleep-demo'
  local debug_mode='false'
  local enabled_mode='auto'

  local -A opts=()
  zparseopts -D -E -A opts -- \
    -count: \
    -jobs: \
    -prefix: \
    -enabled -disabled \
    -debug

  if [[ "${1-}" == '--' ]]; then
    shift
  fi

  if [[ -n "${opts[--count]-}" ]]; then
    count_raw="${opts[--count]}"
  fi
  if [[ -n "${opts[--jobs]-}" ]]; then
    jobs_raw="${opts[--jobs]}"
  fi
  if [[ -n "${opts[--prefix]-}" ]]; then
    prefix="${opts[--prefix]}"
  fi
  if (( ${+opts[--debug]} )); then
    debug_mode='true'
  fi
  if (( ${+opts[--enabled]} )); then
    enabled_mode='true'
  elif (( ${+opts[--disabled]} )); then
    enabled_mode='false'
  fi

  if [[ -z "${count_raw}" || "${count_raw}" != <-> ]]; then
    count_raw='10'
  fi
  local -i count="${count_raw}"
  if (( count <= 0 )); then
    count=10
  fi

  if [[ -z "${jobs_raw}" || "${jobs_raw}" != <-> ]]; then
    jobs_raw='10'
  fi
  local -i jobs="${jobs_raw}"
  if (( jobs <= 0 )); then
    jobs=10
  fi

  local -a items=()
  items=()
  local -i i=0
  for (( i = 1; i <= count; i++ )); do
    items+=("req-${i}")
  done

  local -a args=()
  args=( --worker async_pool_demo::_sleep_worker --jobs "${jobs}" --prefix "${prefix}" )
  if [[ "${debug_mode}" == 'true' ]]; then
    args+=( --debug )
  fi
  if [[ "${enabled_mode}" == 'true' ]]; then
    args+=( --enabled )
  elif [[ "${enabled_mode}" == 'false' ]]; then
    args+=( --disabled )
  fi

  async_pool::map "${args[@]}" -- "${items[@]}"
}
