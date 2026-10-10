#!/usr/bin/env bash
# Warn when upstream's brainstorming skill changed since the splice-ins in
# patches/superpowers-brainstorming/ were last reviewed against it. The build
# only fails when an anchor line moves; this catches changes in meaning.
#
#   check-superpowers.sh           # exit 1 (with hint on stderr) if it changed
#   check-superpowers.sh --accept  # record the locked upstream as reviewed
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
stamp="${root}/patches/superpowers-brainstorming/reviewed"

lock="(builtins.fromJSON (builtins.readFile ${root}/flake.lock)).nodes.superpowers.locked"
rev="$(nix eval --raw --impure --expr "${lock}.rev")"
src="$(nix eval --raw --impure --expr "(builtins.fetchTree ${lock}).outPath")"
hash="$(nix hash path "${src}/skills/brainstorming")"

if [[ "${1:-}" == "--accept" ]]; then
    echo "${rev} ${hash}" >"${stamp}"
    echo "recorded superpowers ${rev} as reviewed"
    exit 0
fi

read -r reviewed_rev reviewed_hash <"${stamp}"
[[ "${hash}" == "${reviewed_hash}" ]] && exit 0

cat >&2 <<EOF
superpowers brainstorming changed upstream since the splice-ins were reviewed:
  https://github.com/obra/superpowers/compare/${reviewed_rev}...${rev}
Re-read patches/superpowers-brainstorming/ against it, then: just accept-superpowers
EOF
exit 1
