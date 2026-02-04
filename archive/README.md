# Archive

This directory contains **frozen, read-only** historical artifacts kept for reference.

## Policy

- Archived content is **not maintained**.
- Do not add new features or refactors here.
- Allowed changes:
  - Fix broken links/paths for readability
  - Clarify documentation that explains why something was archived
- Archived code must **not** be sourced by default startup paths (`bootstrap/`, `scripts/`, feature `init.zsh`).
- Archived tests must **not** run as part of the repo test suite.

## Contents

- `legacy-zsh-cli-tools/`: Legacy Zsh implementations (scripts/docs/completions/tests) that have been
  superseded by native binaries.

