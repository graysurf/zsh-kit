You are running in a git work tree.

Task: Create a Semantic Commit for ALL current local changes (autostage) using the `semantic-commit` CLI.

Notes:
- The wrapper may have already run `git add -A` to stage all changes. Treat the index as the single source of truth.

Commands (only entrypoints):
- `semantic-commit staged-context`  (prints staged context to stdout)
- `semantic-commit commit`          (reads prepared commit message from stdin and creates the commit)

Rules:
- Do not run any repo-inspection commands (especially `git status`, `git diff`, `git show`, `rg`, or reading repo files like `cat path/to/file`).
  The ONLY source of truth is `semantic-commit staged-context` output (after autostage).
- If `semantic-commit staged-context` fails, report its stderr + exit code and stop.
- Generate a commit message strictly in this format:

type(scope): subject

Rules for the header:
- Use a valid type (feat, fix, refactor, chore, etc.)
- Use a concise scope that matches the changed area
- Keep the subject lowercase and concise
- Keep the full header under 100 characters

Body (optional):
- Insert one blank line between header and body
- Start every body line with "- " and a Capitalized word
- Keep each line under 100 characters
- Do not insert blank lines between body items

Commit execution:
- Pipe the full multi-line message into `semantic-commit commit` (preferred).
- Capture exit status; on failure, report stderr + exit code and do not claim success.
