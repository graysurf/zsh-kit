# ────────────────────────────────────────────────────────
# Git commit helpers
# ────────────────────────────────────────────────────────
if command -v safe_unalias >/dev/null; then
  safe_unalias \
    git-commit-to-stash \
    git-commit-context \
    git-commit-context-json
fi

# _git_commit_confirm <prompt>
# Prompt for y/N confirmation (returns 0 only on "y"/"Y").
# Usage: _git_commit_confirm <prompt>
_git_commit_confirm() {
  emulate -L zsh

  typeset prompt="${1-}"
  [[ -n "$prompt" ]] || return 1
  shift || true

  print -n -r -- "$prompt"

  typeset confirm=''
  IFS= read -r confirm
  [[ "$confirm" == [yY] ]]
}

# _git_commit_confirm_or_abort <prompt>
# Prompt for confirmation; print "Aborted" and return non-zero on decline.
# Usage: _git_commit_confirm_or_abort <prompt>
_git_commit_confirm_or_abort() {
  _git_commit_confirm "$@" && return 0
  print "🚫 Aborted"
  return 1
}

# git-commit-to-stash [commit]
# Convert a commit into a stash entry (commit → stash); optionally drop it from history.
# Usage: git-commit-to-stash [commit]
# Notes:
# - Default target is `HEAD`.
# - Captures the commit's patch (parent..commit), not the current working tree.
# - Merge commits: uses first parent (prompts).
# Safety:
# - Dropping a pushed commit rewrites history and may require force push.
git-commit-to-stash() {
  emulate -L zsh
  setopt pipe_fail

  typeset commit_ref='' commit_sha='' parent_sha='' branch_name='' subject=''
  typeset stash_msg='' stash_sha=''
  typeset upstream='' ref_upstream='' merge_parents_count=''

  # ── Safety: ensure we are inside a Git repository ───────────────────────────
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    print "❌ Not a git repository."
    return 1
  fi

  # Target commit (default HEAD)
  commit_ref="${1:-HEAD}"

  # Resolve commit SHA
  commit_sha=$(git rev-parse --verify "${commit_ref}^{commit}" 2>/dev/null)
  if [[ -z "$commit_sha" ]]; then
    print "❌ Cannot resolve commit: $commit_ref"
    return 1
  fi

  # Get parent SHA (handle root commit: no parent)
  parent_sha=$(git rev-parse --verify "${commit_sha}^" 2>/dev/null)
  if [[ -z "$parent_sha" ]]; then
    print "❌ Commit $commit_sha has no parent (root commit)."
    print "🧠 Converting a root commit to stash is ambiguous; aborting."
    return 1
  fi

  # Detect merge commit (multiple parents) and warn
  merge_parents_count=$(git rev-list --parents -n 1 "$commit_sha" | wc -w | tr -d ' ')
  # Output format: <commit> <p1> <p2> ... so count > 2 means multiple parents
  if (( merge_parents_count > 2 )); then
    print "⚠️  Target commit is a merge commit (multiple parents)."
    print "🧠 This tool will use the FIRST parent to compute the patch: ${commit_sha}^1..${commit_sha}"
    _git_commit_confirm_or_abort "❓ Proceed? [y/N] " || return 1
    parent_sha=$(git rev-parse --verify "${commit_sha}^1" 2>/dev/null) || return 1
  fi

  # Gather context for stash message
  branch_name=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || branch_name="(unknown)"
  subject=$(git log -1 --pretty=%s "$commit_sha" 2>/dev/null) || subject="(no subject)"

  # Create a descriptive stash message (includes commit + parent for traceability)
  # Format example:
  #   c2s: commit=abcd123 parent=beef456 branch=feature/x "Refactor parser"
  stash_msg="c2s: commit=${commit_sha[1,7]} parent=${parent_sha[1,7]} branch=${branch_name} \"${subject}\""

  print "🧾 Convert commit → stash"
  print "   Commit : $(git log -1 --oneline "$commit_sha")"
  print "   Parent : ${parent_sha[1,7]}"
  print "   Branch : $branch_name"
  print "   Message: $stash_msg"
  print ""
  print "This will:"
  print "  1) Create a stash entry containing the patch: ${parent_sha[1,7]}..${commit_sha[1,7]}"
  print "  2) Optionally drop the commit from branch history by resetting to parent."
  _git_commit_confirm_or_abort "❓ Proceed to create stash? [y/N] " || return 1

  # ── Create stash entry for the commit's patch ───────────────────────────────
  #
  # We want a stash representing the diff parent..commit, regardless of the current
  # working tree state.
  #
  # Note: `git stash create [<message>]` only snapshots the *current* index/worktree.
  # It cannot directly "stash a commit". To avoid touching the working tree, we
  # synthesize a minimal stash-like commit via `git commit-tree` and then store it
  # via `git stash store`.
  #
  # Stash shape (minimal):
  # - WIP commit tree = <commit_sha>^{tree}
  #   parents:
  #     - base commit  = <parent_sha>
  #     - index commit = synthetic (tree = <parent_sha>^{tree}, parent = <parent_sha>)
  typeset base_tree='' commit_tree='' index_commit='' wip_commit=''
  base_tree=$(git rev-parse --verify "${parent_sha}^{tree}" 2>/dev/null) || base_tree=""
  commit_tree=$(git rev-parse --verify "${commit_sha}^{tree}" 2>/dev/null) || commit_tree=""
  if [[ -n "$base_tree" && -n "$commit_tree" ]]; then
    index_commit=$(git commit-tree "$base_tree" -p "$parent_sha" -m "index on ${branch_name}: ${stash_msg}" 2>/dev/null) || index_commit=""
    if [[ -n "$index_commit" ]]; then
      wip_commit=$(git commit-tree "$commit_tree" -p "$parent_sha" -p "$index_commit" -m "$stash_msg" 2>/dev/null) || wip_commit=""
    fi
  fi

  stash_sha="$wip_commit"

  if [[ -z "$stash_sha" ]]; then
    print "⚠️  Failed to synthesize stash object without touching worktree."
    print "🧠 Fallback would require touching the working tree."
    _git_commit_confirm_or_abort "❓ Fallback by temporarily checking out parent and applying patch (will modify worktree)? [y/N] " || return 1

    # ── Fallback (touches worktree): store patch into stash via temp apply ─────
    # Preconditions: require clean worktree to avoid mixing changes
    if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
      print "❌ Working tree is not clean; fallback requires clean state."
      print "🧠 Commit/stash your current changes first, then retry."
      return 1
    fi

    # Save where we are
    typeset current_head=''
    current_head=$(git rev-parse HEAD 2>/dev/null) || return 1

    # Move to parent in detached HEAD to apply patch cleanly
    if ! git checkout --detach "$parent_sha" >/dev/null 2>&1; then
      print "❌ Failed to checkout parent for fallback."
      return 1
    fi

    # Apply patch (parent..commit) to working tree
    if ! git cherry-pick -n "$commit_sha" >/dev/null 2>&1; then
      print "❌ Failed to apply commit patch in fallback mode."
      print "🧠 Attempting to restore original HEAD."
      git cherry-pick --abort >/dev/null 2>&1
      git checkout "$current_head" >/dev/null 2>&1
      return 1
    fi

    # Now stash the applied changes (includes tracked changes; can add -u if desired)
    if ! git stash push -m "$stash_msg" >/dev/null 2>&1; then
      print "❌ Failed to stash changes in fallback mode."
      git reset --hard >/dev/null 2>&1
      git checkout "$current_head" >/dev/null 2>&1
      return 1
    fi

    # Restore original HEAD
    git reset --hard >/dev/null 2>&1
    git checkout "$current_head" >/dev/null 2>&1

    print "✅ Stash created (fallback): $(git stash list -1)"
  else
    # Store the created stash object into stash list with message
    if ! git stash store -m "$stash_msg" "$stash_sha" >/dev/null 2>&1; then
      print "❌ Failed to store stash object."
      return 1
    fi
    print "✅ Stash created: $(git stash list -1)"
  fi

  # ── Optional: drop the commit from history by resetting current branch ──────
  #
  # This is only safe if:
  # - The commit is at the tip of current branch (HEAD), OR you explicitly want rewrite.
  # We keep it conservative: only offer automatic drop when commit_ref == HEAD.
  if [[ "$commit_ref" != "HEAD" && "$commit_sha" != "$(git rev-parse HEAD 2>/dev/null)" ]]; then
    print "ℹ️  Not dropping commit automatically because target is not HEAD."
    print "🧠 If you want to remove it, do so explicitly (e.g., interactive rebase) after verifying stash."
    return 0
  fi

  print ""
  print "Optional: drop the commit from current branch history?"
  print "  This would run: git reset --hard ${parent_sha[1,7]}"
  print "  (Your work remains in stash; untracked files are unaffected.)"
  if ! _git_commit_confirm "❓ Drop commit from history now? [y/N] "; then
    print "✅ Done. Commit kept; stash saved."
    return 0
  fi

  # Extra warning if commit appears reachable from upstream (heuristic)
  upstream=$(git rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>/dev/null)
  # If commit is an ancestor of upstream or equal/reachable, it was likely pushed
  if [[ -n "$upstream" ]] && git merge-base --is-ancestor "$commit_sha" "$upstream" 2>/dev/null; then
    print "⚠️  This commit appears to be reachable from upstream ($upstream)."
    print "🧨 Dropping it rewrites history and may require force push; it can affect others."
    if ! _git_commit_confirm "❓ Still drop it? [y/N] "; then
      print "✅ Done. Commit kept; stash saved."
      return 0
    fi
  fi

  if ! _git_commit_confirm "❓ Final confirmation: run 'git reset --hard ${parent_sha[1,7]}'? [y/N] "; then
    print "✅ Done. Commit kept; stash saved."
    return 0
  fi

  if ! git reset --hard "$parent_sha"; then
    print "❌ Failed to reset branch to parent."
    print "🧠 Your stash is still saved. You can manually recover the commit via reflog if needed."
    return 1
  fi

  print "✅ Commit dropped from history. Your work is in stash:"
  print "   $(git stash list -1)"
}

# git-commit-context [--stdout|--both] [--no-color]
# Generate a Markdown commit context for the current staged changes.
# Usage: git-commit-context [--stdout|--both] [--no-color] [--include <path/glob>]
# Notes:
# - Includes: scope tree (`git-scope staged`), staged diff, and per-file staged contents (index version).
# - Lockfile contents are hidden by default; use --include to show selected files.
# - Default copies to clipboard via `set_clipboard`; use `--stdout` to print only.
# - `--no-color` also applies when `NO_COLOR` is set.
git-commit-context () {
  emulate -L zsh
  setopt pipe_fail local_traps

  typeset tmpfile='' diff='' scope='' contents='' mode='clipboard'
  typeset no_color=false
  typeset arg=''
  typeset include_arg=''
  typeset -a include_patterns=()
  typeset -a extra_args=()

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    print -u2 -r -- "❌ Not a git repository."
    return 1
  fi

  while [[ $# -gt 0 ]]; do
    arg="${1-}"
    case "$arg" in
      --stdout|-p|--print)
        mode="stdout"
        ;;
      --both)
        mode="both"
        ;;
      --no-color|no-color)
        no_color=true
        ;;
      --include)
        shift
        include_arg="${1-}"
        if [[ -z "$include_arg" ]]; then
          print -u2 -r -- "❌ Missing value for --include"
          return 2
        fi
        include_patterns+=("$include_arg")
        ;;
      --include=*)
        include_patterns+=("${arg#*=}")
        ;;
      --help|-h)
        print -r -- "Usage: git-commit-context [--stdout|--both] [--no-color] [--include <path/glob>]"
        print -r -- "  --stdout   Print commit context to stdout only"
        print -r -- "  --both     Print to stdout and copy to clipboard"
        print -r -- "  --no-color Disable ANSI colors (also via NO_COLOR)"
        print -r -- "  --include  Show full content for selected paths (repeatable)"
        return 0
        ;;
      *)
        extra_args+=("$arg")
        ;;
    esac
    shift
  done

  diff="$(git -c core.quotepath=false diff --cached --no-color)"

  if (( ${#extra_args[@]} > 0 )); then
    print -u2 -r -- "⚠️  Ignoring unknown arguments: ${extra_args[*]}"
  fi

  if [[ -z "$diff" ]]; then
    printf "⚠️  No staged changes to record\n" >&2
    return 1
  fi

  typeset -a scope_args=(staged)
  if [[ "$no_color" == true || -n "${NO_COLOR-}" ]]; then
    scope_args+=(--no-color)
  fi
  scope="$(git-scope "${scope_args[@]}" | sed 's/\x1b\[[0-9;]*m//g')"

  tmpfile="$(mktemp 2>/dev/null || true)"
  if [[ -z "$tmpfile" ]]; then
    tmpfile="$(mktemp -t commit-context.md 2>/dev/null || true)"
  fi
  if [[ -z "$tmpfile" ]]; then
    print -u2 -r -- "❌ Failed to create temp file for commit context."
    return 1
  fi

  trap '[[ -n "${tmpfile-}" ]] && rm -f -- "${tmpfile-}" >/dev/null 2>&1 || true' EXIT

  contents="$(
    git -c core.quotepath=false diff --cached --name-status -z | while IFS= read -r -d '' fstatus; do
      typeset file='' newfile=''
      typeset display_path='' content_path='' numstat='' added='' deleted=''
      typeset include_content=false
      typeset lockfile=false
      typeset binary_file=false
      typeset blob_ref='' blob_size='' blob_type=''

      if [[ -z "$fstatus" ]]; then
        continue
      fi

      case "$fstatus" in
        R*|C*)
          IFS= read -r -d '' file || break
          IFS= read -r -d '' newfile || break
          ;;
        *)
          IFS= read -r -d '' file || break
          ;;
      esac

      display_path="$file"
      content_path="$file"

      if [[ -n "$newfile" ]]; then
        display_path="${file} -> ${newfile}"
        content_path="$newfile"
      fi

      for include_pattern in "${include_patterns[@]}"; do
        if [[ -n "$include_pattern" && "$content_path" == ${~include_pattern} ]]; then
          include_content=true
          break
        fi
      done

      case "${content_path:t}" in
        yarn.lock|package-lock.json|pnpm-lock.yaml|bun.lockb|bun.lock|npm-shrinkwrap.json)
          lockfile=true
          ;;
        *)
          ;;
      esac

      printf "### %s (%s)\n\n" "$display_path" "$fstatus"

      if [[ "$fstatus" == "D" ]]; then
        blob_ref="HEAD:$file"
      else
        blob_ref=":$content_path"
      fi

      numstat="$(git -c core.quotepath=false diff --cached --numstat -- "$content_path" 2>/dev/null | head -n 1)"
      if [[ -n "$numstat" ]]; then
        IFS=$' \t' read -r added deleted _ <<< "$numstat"
        if [[ "$added" == "-" || "$deleted" == "-" ]]; then
          binary_file=true
        fi
      fi

      if [[ "$binary_file" == false && -n "$blob_ref" && -x "$(command -v file)" ]]; then
        if git cat-file -e "$blob_ref" 2>/dev/null; then
          blob_type="$(git cat-file -p "$blob_ref" 2>/dev/null | head -c 8192 | file -b --mime - 2>/dev/null)"
          if [[ "$blob_type" == *"charset=binary"* ]]; then
            binary_file=true
          fi
        fi
      fi

      if [[ "$binary_file" == true ]]; then
        blob_size="$(git cat-file -s "$blob_ref" 2>/dev/null)"
        printf "[Binary file content hidden]\n\n"
        if [[ -n "$blob_size" ]]; then
          printf "Size: %s bytes\n" "$blob_size"
        fi
        if [[ -n "$blob_type" ]]; then
          printf "Type: %s\n" "$blob_type"
        fi
        printf "\n"
        continue
      fi

      if [[ "$lockfile" == true && "$include_content" != true ]]; then
        printf "[Lockfile content hidden]\n\n"
        if [[ -n "$added" && -n "$deleted" && "$added" != "-" && "$deleted" != "-" ]]; then
          printf "Summary: +%s -%s\n" "$added" "$deleted"
        fi
        printf "Tip: use --include %s to show full content\n\n" "$content_path"
        continue
      fi

      if [[ "$fstatus" == "D" ]]; then
        if git cat-file -e "HEAD:$file" 2>/dev/null; then
          printf "[Deleted file, showing HEAD version]\n\n"
          printf '```ts\n'
          git show "HEAD:$file" 2>/dev/null || printf '[HEAD version not found]\n'
          printf '```\n\n'
        else
          printf "[Deleted file, no HEAD version found]\n\n"
        fi
      elif [[ "$fstatus" == "A" || "$fstatus" == "M" || "$fstatus" == R* || "$fstatus" == C* ]]; then
        printf '```ts\n'
        git show :"$content_path" 2>/dev/null || printf '[Index version not found]\n'
        printf '```\n\n'
      else
        printf "[Unhandled status: %s]\n\n" "$fstatus"
      fi
    done
  )"

  printf "%s\n" "# Commit Context

## Input expectations

- Full-file reads are not required for commit message generation.
- Base the message on staged diff, scope tree, and staged (index) version content.

---

## 📂 Scope and file tree:

\`\`\`text
$scope
\`\`\`

## 📄 Git staged diff:

\`\`\`diff
$diff
\`\`\`

  ## 📚 Staged file contents (index version):

$contents" > "$tmpfile"

  if [[ "$mode" == "stdout" ]]; then
    command cat "$tmpfile"
    rm -f -- "$tmpfile" >/dev/null 2>&1 || true
    return 0
  fi

  if [[ "$mode" == "both" ]]; then
    command cat "$tmpfile"
  fi

  command cat "$tmpfile" | set_clipboard
  rm -f -- "$tmpfile" >/dev/null 2>&1 || true

  if [[ "$mode" == "clipboard" ]]; then
    printf "✅ Commit context copied to clipboard with:\n"
    printf "  • Diff\n"
    printf "  • Scope summary (via git-scope staged)\n"
    printf "  • Staged file contents (index version)\n"
  fi
}

# _git_commit_json_escape <string>
# Print a JSON-escaped version of <string> (without surrounding quotes).
# Usage: _git_commit_json_escape <string>
_git_commit_json_escape() {
  emulate -L zsh
  setopt pipe_fail

  typeset s="${1-}"

  typeset out=''
  typeset ch='' hex=''
  typeset -i code=0 i=0

  for (( i = 1; i <= ${#s}; i++ )); do
    ch="${s[i]}"
    case "$ch" in
      $'\\')
        out+='\\'
        ;;
      '"')
        out+='\"'
        ;;
      $'\n')
        out+='\n'
        ;;
      $'\r')
        out+='\r'
        ;;
      $'\t')
        out+='\t'
        ;;
      $'\b')
        out+='\b'
        ;;
      $'\f')
        out+='\f'
        ;;
      *)
        if [[ "$ch" == [[:cntrl:]] ]]; then
          code=$(printf '%d' "'$ch")
          if (( code >= 0 && code <= 31 )); then
            printf -v hex '%02X' "$code"
            out+="\\u00${hex}"
          else
            out+="$ch"
          fi
        else
          out+="$ch"
        fi
        ;;
    esac
  done

  print -r -- "$out"
}

# _git_commit_json_pretty <json>
# Pretty-print JSON (basic formatter; preserves string contents; assumes valid JSON input).
# Usage: _git_commit_json_pretty <json>
_git_commit_json_pretty() {
  emulate -L zsh
  setopt pipe_fail

  typeset json="${1-}"
  typeset -a out=()
  typeset pad=''
  typeset ch=''
  typeset newline=$'\n'
  typeset in_string=false
  typeset escape_next=false
  typeset -i indent=0 i=0

  for (( i = 1; i <= ${#json}; i++ )); do
    ch="${json[i]}"

    if [[ "$in_string" == true ]]; then
      out+=("$ch")
      if [[ "$escape_next" == true ]]; then
        escape_next=false
      else
        [[ "$ch" == $'\\' ]] && escape_next=true
        [[ "$ch" == '"' ]] && in_string=false
      fi
      continue
    fi

    case "$ch" in
      '"')
        in_string=true
        out+=("$ch")
        ;;
      '{'|'[')
        out+=("$ch")
        (( indent++ ))
        out+=("$newline")
        printf -v pad '%*s' $(( indent * 2 )) ''
        out+=("$pad")
        ;;
      '}'|']')
        typeset opener='{'
        [[ "$ch" == ']' ]] && opener='['

        if (( i > 1 )) && [[ "${json[i-1]}" == "$opener" ]]; then
          if (( ${#out[@]} >= 2 )); then
            out[-1]=()
            out[-1]=()
          fi
          (( indent-- ))
          out+=("$ch")
          continue
        fi

        (( indent-- ))
        out+=("$newline")
        printf -v pad '%*s' $(( indent * 2 )) ''
        out+=("$pad")
        out+=("$ch")
        ;;
      ',')
        out+=("$ch")
        out+=("$newline")
        printf -v pad '%*s' $(( indent * 2 )) ''
        out+=("$pad")
        ;;
      ':')
        out+=("$ch")
        out+=(' ')
        ;;
      [[:space:]])
        ;;
      *)
        out+=("$ch")
        ;;
    esac
  done

  print -r -- "${(j::)out}"
}

# git-commit-context-json [--stdout|--both] [--pretty] [--bundle] [--out-dir <path>]
# Generate a compact JSON manifest + staged diff as a standalone `.patch` file.
# Usage: git-commit-context-json [--stdout|--both] [--pretty] [--bundle] [--out-dir <path>]
# Notes:
# - Writes two files:
#   - <out-dir>/commit-context.json
#   - <out-dir>/staged.patch
# - Default copies the JSON manifest to clipboard via `set_clipboard`; use `--stdout` to print only.
# - JSON contains metadata, file list, and stats; the diff is written as `.patch` (not embedded in JSON).
git-commit-context-json() {
  emulate -L zsh
  setopt pipe_fail local_traps

  typeset mode='clipboard'
  typeset pretty=false
  typeset bundle=false
  typeset arg=''
  typeset outdir=''
  typeset git_dir=''
  typeset patch_path='' manifest_path=''
  typeset branch='' head_sha='' generated_at='' repo_name=''
  typeset -i insertions=0 deletions=0 file_count=0 binary_file_count=0 lockfile_count=0
  typeset -i root_file_count=0 top_level_dir_count=0
  typeset -A status_counts=()
  typeset -A top_dir_counts=()
  typeset json=''
  typeset -a extra_args=()
  typeset -a file_objects=()

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    print -u2 -r -- "❌ Not a git repository."
    return 1
  fi

  while [[ $# -gt 0 ]]; do
    arg="${1-}"
    case "$arg" in
      --stdout|-p|--print)
        mode="stdout"
        ;;
      --both)
        mode="both"
        ;;
      --pretty)
        pretty=true
        ;;
      --bundle)
        bundle=true
        ;;
      --out-dir)
        shift
        outdir="${1-}"
        if [[ -z "$outdir" ]]; then
          print -u2 -r -- "❌ Missing value for --out-dir"
          return 2
        fi
        ;;
      --out-dir=*)
        outdir="${arg#*=}"
        ;;
      --help|-h)
        print -r -- "Usage: git-commit-context-json [--stdout|--both] [--pretty] [--bundle] [--out-dir <path>]"
        print -r -- "  --stdout    Print to stdout only (JSON by default; bundle with --bundle)"
        print -r -- "  --both      Print to stdout and copy to clipboard (JSON by default; bundle with --bundle)"
        print -r -- "  --pretty    Pretty-print JSON (default is compact)"
        print -r -- "  --bundle    Print/copy a single bundle (JSON + patch content)"
        print -r -- "  --out-dir   Write files to this directory (default: <git-dir>/commit-context)"
        return 0
        ;;
      *)
        extra_args+=("$arg")
        ;;
    esac
    shift
  done

  if (( ${#extra_args[@]} > 0 )); then
    print -u2 -r -- "⚠️  Ignoring unknown arguments: ${extra_args[*]}"
  fi

  if git diff --cached --quiet --exit-code; then
    print -u2 -r -- "⚠️  No staged changes to record"
    return 1
  fi

  if [[ -z "$outdir" ]]; then
    git_dir="$(git rev-parse --git-dir 2>/dev/null || true)"
    if [[ -z "$git_dir" ]]; then
      print -u2 -r -- "❌ Failed to resolve git dir."
      return 1
    fi
    outdir="${git_dir%/}/commit-context"
  fi

  if ! mkdir -p -- "$outdir" 2>/dev/null; then
    print -u2 -r -- "❌ Failed to create output directory: $outdir"
    return 1
  fi

  patch_path="${outdir%/}/staged.patch"
  manifest_path="${outdir%/}/commit-context.json"

  if ! git -c core.quotepath=false diff --cached --no-color > "$patch_path"; then
    print -u2 -r -- "❌ Failed to write staged patch: $patch_path"
    return 1
  fi

  branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
  head_sha="$(git rev-parse --short HEAD 2>/dev/null || true)"
  generated_at="$(date -u +'%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || true)"
  repo_name="$(basename -- "$(git rev-parse --show-toplevel 2>/dev/null || print -r -- '')" 2>/dev/null || true)"

  while IFS= read -r -d '' fstatus; do
    typeset file='' newfile=''
    typeset status_letter='' status_score=''
    typeset file_path='' old_file_path=''
    typeset numstat='' added='' deleted=''
    typeset binary_file=false
    typeset lockfile=false
    typeset ins_json='null' del_json='null'

    [[ -n "$fstatus" ]] || continue

    case "$fstatus" in
      R*|C*)
        IFS= read -r -d '' file || break
        IFS= read -r -d '' newfile || break
        old_file_path="$file"
        file_path="$newfile"
        ;;
      *)
        IFS= read -r -d '' file || break
        file_path="$file"
        ;;
    esac

    status_letter="${fstatus[1,1]}"
    status_score="${fstatus[2,-1]}"
    [[ -n "$status_score" ]] || status_score=""

    (( status_counts[$status_letter]++ ))
    if [[ "$file_path" == */* ]]; then
      typeset top_dir="${file_path%%/*}"
      (( top_dir_counts[$top_dir]++ ))
    else
      (( root_file_count++ ))
    fi

    case "${file_path:t}" in
      yarn.lock|package-lock.json|pnpm-lock.yaml|bun.lockb|bun.lock|npm-shrinkwrap.json)
        lockfile=true
        ;;
      *)
        ;;
    esac

    numstat="$(git -c core.quotepath=false diff --cached --numstat -- "$file_path" 2>/dev/null | head -n 1)"
    if [[ -n "$numstat" ]]; then
      IFS=$' \t' read -r added deleted _ <<< "$numstat"
      if [[ "$added" == "-" || "$deleted" == "-" ]]; then
        binary_file=true
      else
        ins_json="$added"
        del_json="$deleted"
        (( insertions += added ))
        (( deletions += deleted ))
      fi
    fi

    if [[ "$binary_file" == true ]]; then
      (( binary_file_count++ ))
    fi
    if [[ "$lockfile" == true ]]; then
      (( lockfile_count++ ))
    fi

    typeset path_json='' old_path_json=''
    path_json="$(_git_commit_json_escape "$file_path")"
    old_path_json="$(_git_commit_json_escape "$old_file_path")"

    typeset obj=''
    obj="{\"path\":\"${path_json}\",\"status\":\"${status_letter}\""
    if [[ -n "$status_score" ]]; then
      obj+=",\"score\":${status_score}"
    fi
    if [[ -n "$old_file_path" ]]; then
      obj+=",\"oldPath\":\"${old_path_json}\""
    fi
    obj+=",\"insertions\":${ins_json},\"deletions\":${del_json},\"binary\":$([[ "$binary_file" == true ]] && print -r -- true || print -r -- false),\"lockfile\":$([[ "$lockfile" == true ]] && print -r -- true || print -r -- false)}"

    file_objects+=("$obj")
    (( file_count++ ))
  done < <(git -c core.quotepath=false diff --cached --name-status -z)

  typeset files_json='[]'
  if (( ${#file_objects[@]} > 0 )); then
    files_json="[${(j:,:)file_objects}]"
  fi

  top_level_dir_count=${#top_dir_counts}

  typeset -a status_objects=()
  typeset status_counts_json='[]'
  for status_letter in ${(ok)status_counts}; do
    status_objects+=("{\"status\":\"$(_git_commit_json_escape "$status_letter")\",\"count\":${status_counts[$status_letter]}}")
  done
  if (( ${#status_objects[@]} > 0 )); then
    status_counts_json="[${(j:,:)status_objects}]"
  fi

  typeset -a top_dir_objects=()
  typeset top_dirs_json='[]'
  for top_dir in ${(ok)top_dir_counts}; do
    top_dir_objects+=("{\"name\":\"$(_git_commit_json_escape "$top_dir")\",\"count\":${top_dir_counts[$top_dir]}}")
  done
  if (( ${#top_dir_objects[@]} > 0 )); then
    top_dirs_json="[${(j:,:)top_dir_objects}]"
  fi

  typeset branch_json='null'
  if [[ -n "$branch" ]]; then
    branch_json="\"$(_git_commit_json_escape "$branch")\""
  fi

  typeset head_json='null'
  if [[ -n "$head_sha" ]]; then
    head_json="\"$(_git_commit_json_escape "$head_sha")\""
  fi

  typeset generated_at_json='null'
  if [[ -n "$generated_at" ]]; then
    generated_at_json="\"$(_git_commit_json_escape "$generated_at")\""
  fi

  typeset repo_name_json='null'
  if [[ -n "$repo_name" ]]; then
    repo_name_json="\"$(_git_commit_json_escape "$repo_name")\""
  fi

  json="{\"schemaVersion\":1"
  json+=",\"generatedAt\":${generated_at_json}"
  json+=",\"repo\":{\"name\":${repo_name_json}}"
  json+=",\"git\":{\"branch\":${branch_json},\"head\":${head_json}}"
  json+=",\"staged\":{\"summary\":{\"fileCount\":${file_count},\"insertions\":${insertions},\"deletions\":${deletions},\"binaryFileCount\":${binary_file_count},\"lockfileCount\":${lockfile_count},\"rootFileCount\":${root_file_count},\"topLevelDirCount\":${top_level_dir_count}},\"statusCounts\":${status_counts_json},\"structure\":{\"topLevelDirs\":${top_dirs_json}},\"files\":${files_json},\"patch\":{\"path\":\"staged.patch\",\"format\":\"git diff --cached\"}}"
  json+="}"

  if [[ "$pretty" == true ]]; then
    json="$(_git_commit_json_pretty "$json")"
  fi

  if ! printf "%s\n" "$json" > "$manifest_path"; then
    print -u2 -r -- "❌ Failed to write JSON manifest: $manifest_path"
    return 1
  fi

  if [[ "$mode" == "stdout" ]]; then
    if [[ "$bundle" == true ]]; then
      print -r -- "===== commit-context.json ====="
      printf "%s\n" "$json"
      print -r -- ""
      print -r -- "===== staged.patch ====="
      command cat "$patch_path"
    else
      printf "%s\n" "$json"
    fi
    return 0
  fi

  if [[ "$mode" == "both" ]]; then
    if [[ "$bundle" == true ]]; then
      print -r -- "===== commit-context.json ====="
      printf "%s\n" "$json"
      print -r -- ""
      print -r -- "===== staged.patch ====="
      command cat "$patch_path"
    else
      printf "%s\n" "$json"
    fi
  fi

  if [[ "$bundle" == true ]]; then
    {
      print -r -- "===== commit-context.json ====="
      printf "%s\n" "$json"
      print -r -- ""
      print -r -- "===== staged.patch ====="
      command cat "$patch_path"
    } | set_clipboard
  else
    printf "%s" "$json" | set_clipboard
  fi

  if [[ "$mode" == "clipboard" ]]; then
    printf "✅ JSON commit context copied to clipboard with:\n"
    if [[ "$bundle" == true ]]; then
      printf "  • Bundle (JSON + patch)\n"
    else
      printf "  • JSON manifest\n"
    fi
    printf "  • Patch file written to: %s\n" "$patch_path"
    printf "  • Manifest file written to: %s\n" "$manifest_path"
  fi
}
