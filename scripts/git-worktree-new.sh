#!/usr/bin/env bash
# Create a new worktree with a fresh branch off origin/main: git wb <branch>
# Sibling layout (matches git bclone):
#   reponame/
#   ├── .bare/
#   ├── main/        current worktree
#   └── <branch>/    new worktree (slashes in <branch> nest)
# Outputs the new worktree path on the last line for shell wrapping.
set -euo pipefail

[[ $# -lt 1 ]] && { echo "Usage: git wb <branch>" >&2; exit 1; }

branch=$1

git fetch origin

# Place the new worktree beside the current one, regardless of cwd within it.
top=$(git rev-parse --show-toplevel)
dest="$(dirname "${top}")/${branch}"

git worktree add -b "${branch}" "${dest}" origin/main

echo "${dest}"
