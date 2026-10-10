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

# git worktree remove deletes ignored files without --force, and git meta puts
# docs/specs and docs/plans in info/exclude. Refuse while any of them is missing
# from .meta or differs from the archived copy.
meta="$(dirname "$(cd "$(git rev-parse --git-common-dir)" && pwd -P)")/.meta"
unsaved=()
while IFS= read -r -d '' f; do
  cmp -s "${dest}/${f}" "${meta}/${f}" || unsaved+=("${f}")
done < <(git -C "${dest}" ls-files -z --others --ignored --exclude-standard -- docs/specs docs/plans)
if [[ ${#unsaved[@]} -gt 0 ]]; then
  echo "refusing: ${dest} has specs/plans not saved in .meta:" >&2
  printf '  %s\n' "${unsaved[@]}" >&2
  echo "copy them into ${meta} ('git meta link' adds new files but never overwrites), then retry" >&2
  exit 1
fi

git worktree remove "${dest}"

if ! git branch -d "${branch}"; then
  echo "worktree removed; branch '${branch}' kept (unmerged). Delete with: git branch -D ${branch}" >&2
fi
