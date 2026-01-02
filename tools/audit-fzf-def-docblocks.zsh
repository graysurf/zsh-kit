#!/usr/bin/env -S zsh -f

setopt pipe_fail err_exit nounset

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr SCRIPT_NAME="${SCRIPT_PATH:t}"
typeset -gr SCRIPT_HINT="./tools/$SCRIPT_NAME"

# print_usage: Print CLI usage/help.
print_usage() {
  emulate -L zsh
  setopt pipe_fail nounset

  print -r -- "Usage: $SCRIPT_HINT [--check] [--stdout] [--out <file>] [paths...] [-h|--help]"
  print -r --
  print -r -- "Purpose:"
  print -r -- "  Audit first-party zsh files for fzf-def docblock coverage."
  print -r --
  print -r -- "Input:"
  print -r -- "  (default) Audit first-party files: .zshrc, .zprofile, scripts/, bootstrap/, tools/"
  print -r -- "  paths... : One or more files/directories to audit instead (directories scan *.zsh)"
  print -r --
  print -r -- "Checks:"
  print -r -- "  --check : exit non-zero if gaps (missing docblocks) exist"
  print -r --
  print -r -- "Output:"
  print -r -- "  (default) Write report to: \${ZSH_CACHE_DIR}/fzf-def-docblocks-audit.txt"
  print -r -- "  --stdout: Print the report to stdout (no file write unless --out or env is set)"
  print -r -- "  --out   : Write report to the given file path"
  print -r --
  print -r -- "Env:"
  print -r -- "  FZF_DEF_DOC_AUDIT_OUT: Default output path (overrides the default cache path)"
  print -r --
  print -r -- "Examples:"
  print -r -- "  $SCRIPT_HINT"
  print -r -- "  $SCRIPT_HINT --stdout"
  print -r -- "  $SCRIPT_HINT --out /path/to/report.txt"
  print -r -- "  FZF_DEF_DOC_AUDIT_OUT=/tmp/report.txt $SCRIPT_HINT"
}

# repo_root_from_script: Resolve the repo root directory from this script path.
repo_root_from_script() {
  emulate -L zsh
  setopt pipe_fail nounset

  typeset script_dir='' root_dir=''
  script_dir="${SCRIPT_PATH:h}"
  root_dir="${script_dir:h}"
  print -r -- "$root_dir"
}

# audit_cache_dir: Resolve the default cache directory.
audit_cache_dir() {
  emulate -L zsh
  setopt pipe_fail nounset

  typeset cache_dir=''
  if [[ -n "${ZSH_CACHE_DIR-}" ]]; then
    cache_dir="$ZSH_CACHE_DIR"
  elif [[ -n "${ZDOTDIR-}" ]]; then
    cache_dir="$ZDOTDIR/cache"
  else
    cache_dir=$ZSH_CACHE_DIR
  fi
  print -r -- "$cache_dir"
}

# list_first_party_files <root_dir>
# Print the list of first-party files to audit (matches fzf-def indexing scope).
list_first_party_files() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset root_dir="$1"
  typeset -a files=()
  typeset file='' dir=''

  [[ -f "$root_dir/.zshrc" ]] && files+=("$root_dir/.zshrc")
  [[ -f "$root_dir/.zprofile" ]] && files+=("$root_dir/.zprofile")

  for dir in "$root_dir/scripts" "$root_dir/bootstrap" "$root_dir/tools"; do
    [[ -d "$dir" ]] || continue
    while IFS= read -r file; do
      [[ -n "$file" ]] && files+=("$file")
    done < <(command find "$dir" -type f -name '*.zsh' -print 2>/dev/null | command sort)
  done

  print -rl -- "${files[@]}"
}

# list_files_from_paths [paths...]
# Expand file/dir paths into absolute .zsh file paths (directories recurse).
# Usage: list_files_from_paths [paths...]
list_files_from_paths() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset -A seen=()
  typeset -a files=()
  typeset input_path='' abs='' file=''

  for input_path in "$@"; do
    [[ -n "$input_path" ]] || continue

    if [[ ! -e "$input_path" ]]; then
      print -u2 -r -- "❌ Path not found: $input_path"
      return 2
    fi

    abs="${input_path:A}"
    if [[ -d "$abs" ]]; then
      while IFS= read -r file; do
        [[ -n "$file" ]] || continue
        [[ -n "${seen[$file]-}" ]] && continue
        seen[$file]=1
        files+=("$file")
      done < <(command find "$abs" -type f -name '*.zsh' -print 2>/dev/null | command sort)
      continue
    fi

    if [[ -f "$abs" ]]; then
      if [[ "$abs" != *.zsh ]]; then
        print -u2 -r -- "❌ Not a .zsh file: $input_path"
        return 2
      fi
      [[ -n "${seen[$abs]-}" ]] && continue
      seen[$abs]=1
      files+=("$abs")
      continue
    fi
  done

  print -rl -- "${files[@]}"
}

typeset -gi FN_TOTAL=0
typeset -gi FN_WITH_DOC=0
typeset -gi FN_INTERNAL_TOTAL=0
typeset -gi FN_INTERNAL_WITH_DOC=0
typeset -gi FN_PUBLIC_TOTAL=0
typeset -gi FN_PUBLIC_WITH_DOC=0

typeset -gi ALIAS_TOTAL=0
typeset -gi ALIAS_WITH_DOC=0

typeset -ga GAP_DEFS=()

# record_def <kind> <name> <file_rel> <line_no> <has_doc>
record_def() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset kind="$1" name="$2" file_rel="$3" line_no="$4" has_doc="$5"

  case "$kind" in
    fn)
      (( ++FN_TOTAL ))
      if [[ "$name" == _* ]]; then
        (( ++FN_INTERNAL_TOTAL ))
        if [[ "$has_doc" == 1 ]]; then
          (( ++FN_WITH_DOC ))
          (( ++FN_INTERNAL_WITH_DOC ))
        else
          GAP_DEFS+=("${file_rel}"$'\t'"${line_no}"$'\t'"fn"$'\t'"${name}")
        fi
      else
        (( ++FN_PUBLIC_TOTAL ))
        if [[ "$has_doc" == 1 ]]; then
          (( ++FN_WITH_DOC ))
          (( ++FN_PUBLIC_WITH_DOC ))
        else
          GAP_DEFS+=("${file_rel}"$'\t'"${line_no}"$'\t'"fn"$'\t'"${name}")
        fi
      fi
      ;;
    alias)
      (( ++ALIAS_TOTAL ))
      if [[ "$has_doc" == 1 ]]; then
        (( ++ALIAS_WITH_DOC ))
      else
        GAP_DEFS+=("${file_rel}"$'\t'"${line_no}"$'\t'"alias"$'\t'"${name}")
      fi
      ;;
    *)
      print -u2 -r -- "record_def: unknown kind: $kind"
      return 2
      ;;
  esac
}

# audit_file <root_dir> <file>
# Scan a file for function/alias definitions and whether they have attached docblocks.
audit_file() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset root_dir="$1"
  typeset file="$2"
  [[ -r "$file" ]] || return 0

  typeset file_rel="${file#$root_dir/}"
  typeset -a comment_buf=()
  typeset line='' name=''
  typeset -i line_no=0

  while IFS= read -r line; do
    (( ++line_no ))

    if [[ "$line" =~ '^[[:space:]]*#' ]]; then
      comment_buf+=("$line")
      continue
    fi

    if [[ "$line" =~ '^[[:space:]]*$' ]]; then
      comment_buf=()
      continue
    fi

    if [[ "$line" =~ '^[[:space:]]*function[[:space:]]+([A-Za-z0-9_][A-Za-z0-9_:-]*)[[:space:]]*(\(\))?[[:space:]]*\{' ]]; then
      name="${match[1]}"
      record_def fn "$name" "$file_rel" "$line_no" "$(( ${#comment_buf} > 0 ? 1 : 0 ))"
      comment_buf=()
      continue
    fi

    if [[ "$line" =~ '^[[:space:]]*([A-Za-z0-9_][A-Za-z0-9_:-]*)[[:space:]]*\(\)[[:space:]]*\{' ]]; then
      name="${match[1]}"
      record_def fn "$name" "$file_rel" "$line_no" "$(( ${#comment_buf} > 0 ? 1 : 0 ))"
      comment_buf=()
      continue
    fi

    if [[ "$line" =~ '^[[:space:]]*alias[[:space:]]+(-g[[:space:]]+)?([A-Za-z0-9_][A-Za-z0-9_:-]*)[[:space:]]*=' ]]; then
      name="${match[2]}"
      record_def alias "$name" "$file_rel" "$line_no" "$(( ${#comment_buf} > 0 ? 1 : 0 ))"
      comment_buf=()
      continue
    fi

    comment_buf=()
  done < "$file"
}

# safe_pct <have> <total>
# Print percent as an integer (0-100).
safe_pct() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset have="$1" total="$2"
  if [[ "$total" == 0 ]]; then
    print -r -- 0
    return 0
  fi
  print -r -- "$(( (have * 100) / total ))"
}

# write_report <root_dir> <timestamp>
# Print the audit report to stdout.
write_report() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset root_dir="$1"
  typeset ts="$2"

  typeset fn_pct="$(safe_pct "$FN_WITH_DOC" "$FN_TOTAL")"
  typeset fn_internal_pct="$(safe_pct "$FN_INTERNAL_WITH_DOC" "$FN_INTERNAL_TOTAL")"
  typeset fn_public_pct="$(safe_pct "$FN_PUBLIC_WITH_DOC" "$FN_PUBLIC_TOTAL")"
  typeset alias_pct="$(safe_pct "$ALIAS_WITH_DOC" "$ALIAS_TOTAL")"

  print -r -- "# fzf-def docblock audit"
  print -r -- "timestamp: $ts"
  print -r -- "root: $root_dir"
  print -r --
  print -r -- "## Baseline"
  print -r -- "functions: ${FN_WITH_DOC}/${FN_TOTAL} (${fn_pct}%)"
  print -r -- "  internal (_*): ${FN_INTERNAL_WITH_DOC}/${FN_INTERNAL_TOTAL} (${fn_internal_pct}%)"
  print -r -- "  public      : ${FN_PUBLIC_WITH_DOC}/${FN_PUBLIC_TOTAL} (${fn_public_pct}%)"
  print -r -- "aliases  : ${ALIAS_WITH_DOC}/${ALIAS_TOTAL} (${alias_pct}%)"
  print -r --

  print -r -- "## Gaps (missing docblocks)"
  if (( ${#GAP_DEFS[@]} == 0 )); then
    print -r -- "(none)"
    return 0
  fi

  typeset -a sorted=()
  sorted=("${(@f)$(printf '%s\n' "${GAP_DEFS[@]}" | command sort -t $'\t' -k1,1 -k2,2n -k3,3 -k4,4)}")

  typeset row='' file_rel='' line_no='' kind='' name=''
  for row in "${sorted[@]}"; do
    IFS=$'\t' read -r file_rel line_no kind name <<< "$row"
    print -r -- "- ${kind}: ${name} (${file_rel}:${line_no})"
  done
  return 0
}

# main [args...]
# CLI entrypoint.
main() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  zmodload zsh/zutil 2>/dev/null || {
    print -u2 -r -- "❌ zsh/zutil is required for zparseopts."
    return 1
  }

  typeset -A opts=()
  zparseopts -D -E -A opts -- h -help c -check -stdout o: -out: || return 2

  if (( ${+opts[-h]} || ${+opts[--help]} )); then
    print_usage
    return 0
  fi

  typeset want_check=0
  (( ${+opts[-c]} || ${+opts[--check]} )) && want_check=1

  typeset want_stdout=0
  (( ${+opts[--stdout]} )) && want_stdout=1

  typeset out_file="${opts[--out]-}"
  [[ -z "$out_file" ]] && out_file="${opts[-o]-}"

  typeset write_file=0
  if [[ -n "$out_file" ]]; then
    write_file=1
  elif [[ -n "${FZF_DEF_DOC_AUDIT_OUT-}" ]]; then
    out_file="$FZF_DEF_DOC_AUDIT_OUT"
    write_file=1
  elif (( !want_stdout )); then
    out_file="$(audit_cache_dir)/fzf-def-docblocks-audit.txt"
    write_file=1
  fi

  if (( write_file )) && [[ -z "$out_file" ]]; then
    print -u2 -r -- "❌ Missing output file path"
    return 2
  fi

  typeset root_dir=''
  root_dir="$(repo_root_from_script)"

  typeset ts=''
  ts="$(date '+%Y-%m-%d %H:%M:%S %z')"

  typeset -a files=()
  if (( $# > 0 )); then
    typeset files_raw=''
    files_raw="$(list_files_from_paths "$@")"
    typeset -i files_rc=$?
    if (( files_rc != 0 )); then
      return "$files_rc"
    fi
    files=("${(@f)files_raw}")
  else
    files=("${(@f)$(list_first_party_files "$root_dir")}")
  fi

  typeset file=''
  for file in "${files[@]}"; do
    audit_file "$root_dir" "$file"
  done

  typeset tmp_dir='' tmp_file=''
  tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t zsh-kit-audit.XXXXXX)"
  tmp_file="$tmp_dir/fzf-def-docblocks-audit.txt"

  write_report "$root_dir" "$ts" >| "$tmp_file"

  if (( want_stdout )); then
    command cat -- "$tmp_file"
  fi

  if (( write_file )); then
    typeset out_dir="${out_file:h}"
    [[ -d "$out_dir" ]] || command mkdir -p -- "$out_dir"
    command cat -- "$tmp_file" >| "$out_file"
    if (( want_stdout )); then
      print -u2 -r -- "Wrote audit report: $out_file"
    else
      print -r -- "Wrote audit report: $out_file"
    fi
  fi

  typeset -i exit_code=0
  if (( want_check )) && (( ${#GAP_DEFS[@]} > 0 )); then
    exit_code=1
  fi

  rm -rf -- "$tmp_dir"
  return "$exit_code"
}

main "$@"
