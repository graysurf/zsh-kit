# AGENTS

## Scope

- This file defines project-level instructions for any agent working in this repository.

## Branch and PR Target Policy

- The active development branch for this repository is `nils-cli`.
- Agents MUST treat `nils-cli` as the default base branch for all implementation work, unless the user explicitly instructs otherwise.
- All GitHub PR operations (including create, review, merge, and close workflows) MUST target `nils-cli` as the base branch, not `main`.

## Testing (Required After Code Changes)

- After any code change, run the tests exactly as described in `DEVELOPMENT.md`.
- Report the results clearly, including the commands executed and whether they passed or failed.
- If tests cannot be run, explicitly state the reason and what you would run.
