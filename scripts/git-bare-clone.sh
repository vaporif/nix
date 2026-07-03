#!/usr/bin/env bash
# Bare clone with sibling worktrees: git bclone <repo-url>
# Creates reponame/ with .bare/ (git dir) + a worktree for the default branch.
# Layout:
#   reponame/
#   ├── .bare/            bare repo
#   ├── .git              file: "gitdir: ./.bare"
#   └── <default-branch>/ worktree
# Outputs final worktree path on last line for shell wrapper.
set -euo pipefail

[[ $# -lt 1 ]] && { echo "Usage: git bclone <repo-url>" >&2; exit 1; }

repo_name=$(basename "$1" .git)
mkdir "${repo_name}"
cd "${repo_name}"

git clone --bare "$1" .bare
echo "gitdir: ./.bare" > .git

# Bare clones omit the origin fetch refspec, so `git fetch` would populate local
# heads instead of origin/*. Restore normal clone behaviour.
git config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'

default=$(git symbolic-ref --short HEAD)
git worktree add "${default}" "${default}"

echo "${repo_name}/${default}"
