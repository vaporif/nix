#!/usr/bin/env bash
# Check/bump vendored librewolf-unwrapped to the latest LibreWolf (Codeberg) tag.
# The bump delegates to the package's update.nix; this guard adds a nix-free --check.
#
# Usage:
#   update-librewolf.sh           # bump pkgs/librewolf-unwrapped/src.json in place
#   update-librewolf.sh --check   # exit 1 if a newer version exists

set -euo pipefail

readonly TAGS_API="https://codeberg.org/api/v1/repos/librewolf/source/tags?page=1&limit=1"
readonly UPDATE_ATTR="#darwinConfigurations.burnedapple.pkgs.librewolf-unwrapped.updateScript"

REPO_ROOT="$(git -C "$(dirname -- "$0")" rev-parse --show-toplevel)"
readonly REPO_ROOT
readonly SRC_JSON="${REPO_ROOT}/pkgs/librewolf-unwrapped/src.json"

die() {
    echo "error: $*" >&2
    exit 2
}

current_version() {
    jq -r '.packageVersion' "${SRC_JSON}"
}

latest_version() {
    curl -sfL --max-time 10 "${TAGS_API}" | jq -r '.[0].name'
}

do_check() {
    local cur lat
    cur="$(current_version)"
    lat="$(latest_version)"
    if [[ -z "${cur}" || -z "${lat}" ]]; then
        die "could not read current (${cur}) or latest (${lat}) version"
    fi
    if [[ "${cur}" == "${lat}" ]]; then
        echo "librewolf up to date (${cur})"
        return 0
    fi
    echo "librewolf ${lat} available (currently ${cur}) — run \`just update-librewolf\`" >&2
    return 1
}

do_update() {
    [[ -f "${SRC_JSON}" ]] || die "missing ${SRC_JSON}"

    # update.nix re-checks the tag and no-ops when current, so no gate needed.
    local script
    script="$(nix --extra-experimental-features 'nix-command flakes' \
        build --no-link --print-out-paths "${REPO_ROOT}${UPDATE_ATTR}")" \
        || die "could not build updateScript (${UPDATE_ATTR})"

    (cd "${REPO_ROOT}" && "${script}")

    echo "  done. review the diff with: git diff -- ${SRC_JSON}"
}

main() {
    case "${1:-}" in
        --check) do_check ;;
        "") do_update ;;
        --help | -h) sed -n '2,/^$/ s/^# \{0,1\}//p' "$0" ;;
        *) die "unknown option: $1" ;;
    esac
}

main "$@"
