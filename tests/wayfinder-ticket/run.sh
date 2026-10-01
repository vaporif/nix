#!/usr/bin/env bash
# Usage: WT=<wayfinder-ticket> BCLONE=<git-bare-clone.sh> [WT_COMMANDS="..."] run.sh [pattern]
set -u

: "${WT:?WT must point at the wayfinder-ticket binary}"
: "${BCLONE:?BCLONE must point at scripts/git-bare-clone.sh}"
: "${WT_COMMANDS:=}"
export WT BCLONE WT_COMMANDS

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

TMPDIR=$(realpath "${TMPDIR:-/tmp}")
export TMPDIR
export HOME=$TMPDIR
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
export GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
unset AGENT_SESSION_ID WAYFINDER_AGENT_PID WAYFINDER_AGENT_START WAYFINDER_HARNESS
git config --global init.defaultBranch main
git config --global advice.detachedHead false
mkdir -p "$HOME/.config/git"
printf '.claude\n' >"$HOME/.config/git/ignore"

# Under an agent's Bash tool the process walk finds a real agent, so cases that
# need "no agent ancestor" can only be checked in the nix build.
if "$WT" __agent-pid >/dev/null 2>&1; then
  WT_AGENT_ANCESTOR=1
else
  WT_AGENT_ANCESTOR=0
fi
export WT_AGENT_ANCESTOR

# shellcheck source=/dev/null
source "$here/fixtures.sh"
for f in "$here"/*.sh; do
  case $(basename "$f") in
  run.sh | fixtures.sh) ;;
  *)
    # shellcheck source=/dev/null
    source "$f"
    ;;
  esac
done

pattern=${1:-}
failed=0
for name in $(declare -F | awk '{print $3}' | grep '^test_' | grep -e "$pattern"); do
  dir=$TMPDIR/case-$name
  if [ -e "$dir" ]; then
    chmod -R u+w "$dir"
    rm -rf "$dir"
  fi
  mkdir -p "$dir"
  (
    cd "$dir" || exit 1
    trap 'set +e; kill $(jobs -p) 2>/dev/null; for f in "${TMPDIR:-/tmp}"/wayfinder-*/*.pid; do [ -e "$f" ] && kill "$(head -1 "$f")" 2>/dev/null; done' EXIT
    set -eo pipefail
    if [ -n "${WT_TRACE:-}" ]; then set -x; fi
    "$name"
  ) >"$dir.log" 2>&1
  rc=$?
  case $rc in
  0) echo "ok $name" ;;
  77) echo "skip $name" ;;
  *)
    echo "FAIL $name"
    sed 's/^/    /' "$dir.log"
    failed=1
    ;;
  esac
done
exit $failed
