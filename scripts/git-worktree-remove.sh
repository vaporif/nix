#!/usr/bin/env bash
# Remove a sibling worktree and its branch: git wr <branch>
# Complements `git wb`: tears down the worktree at ../<branch> and deletes the
# local branch. The branch is deleted safely (git branch -d); if it has unmerged
# commits, the worktree is still removed and you delete the branch manually.
set -euo pipefail

[[ $# -lt 1 ]] && { echo "Usage: git wr <branch>" >&2; exit 1; }

branch=$1

top=$(git rev-parse --show-toplevel)
dest="$(dirname "${top}")/${branch}"

git worktree remove "${dest}"

if ! git branch -d "${branch}"; then
  echo "worktree removed; branch '${branch}' kept (unmerged). Delete with: git branch -D ${branch}" >&2
fi
