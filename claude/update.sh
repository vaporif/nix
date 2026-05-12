#!/usr/bin/env bash
# Update vendored claude-code package to the latest @anthropic-ai/claude-code release.
#
# Sources of truth:
#   - version: https://registry.npmjs.org/@anthropic-ai/claude-code/latest
#   - binary:  https://downloads.claude.ai/claude-code-releases/<version>/<platform>/claude
#
# Hashes are computed locally via nix-prefetch-url; trust surface is Anthropic's CDN
# plus the npm registry (for version discovery only — never for the binary itself).
#
# Usage:
#   update.sh           # bump claude/package.nix in place
#   update.sh --check   # exit 1 (with hint on stderr) if a newer version exists

set -euo pipefail

readonly NPM_URL="https://registry.npmjs.org/@anthropic-ai/claude-code/latest"
readonly CDN_BASE="https://downloads.claude.ai/claude-code-releases"
readonly PLATFORMS=("darwin-arm64" "darwin-x64" "linux-x64" "linux-arm64")

REPO_ROOT="$(git -C "$(dirname -- "$0")" rev-parse --show-toplevel)"
readonly REPO_ROOT
readonly PACKAGE_FILE="${REPO_ROOT}/claude/package.nix"

die() {
    echo "error: $*" >&2
    exit 2
}

current_version() {
    sed -n 's/^[[:space:]]*version = "\([^"]*\)";.*/\1/p' "${PACKAGE_FILE}" | head -n1
}

latest_version() {
    curl -sfL --max-time 10 "${NPM_URL}" | jq -r '.version'
}

prefetch_hash() {
    local version="$1" platform="$2"
    nix-prefetch-url --type sha256 "${CDN_BASE}/${version}/${platform}/claude" 2>/dev/null | tail -n1
}

rewrite_version() {
    local new_version="$1"
    sed -i.bak -E "s/^([[:space:]]*version = \")[^\"]*(\";.*)$/\1${new_version}\2/" "${PACKAGE_FILE}"
    rm -f "${PACKAGE_FILE}.bak"
}

rewrite_hash() {
    local platform="$1" hash="$2"
    sed -i.bak -E "s|^([[:space:]]*\"${platform}\" = \")[^\"]*(\";.*)$|\1${hash}\2|" "${PACKAGE_FILE}"
    rm -f "${PACKAGE_FILE}.bak"
}

do_check() {
    local cur lat
    cur="$(current_version)"
    lat="$(latest_version)"
    if [[ -z "${cur}" || -z "${lat}" ]]; then
        die "could not read current (${cur}) or latest (${lat}) version"
    fi
    if [[ "${cur}" == "${lat}" ]]; then
        echo "claude-code up to date (${cur})"
        return 0
    fi
    echo "claude-code ${lat} available (currently ${cur}) — run \`just llm-update\`" >&2
    return 1
}

do_update() {
    [[ -f "${PACKAGE_FILE}" ]] || die "missing ${PACKAGE_FILE}"
    command -v nix-prefetch-url >/dev/null || die "nix-prefetch-url not in PATH"
    command -v jq >/dev/null || die "jq not in PATH"

    local cur lat
    cur="$(current_version)"
    lat="$(latest_version)"
    if [[ -z "${cur}" || -z "${lat}" ]]; then
        die "could not read current (${cur}) or latest (${lat}) version"
    fi

    if [[ "${cur}" == "${lat}" ]]; then
        echo "claude-code already at ${cur}"
        return 0
    fi

    echo "claude-code: ${cur} -> ${lat}"
    rewrite_version "${lat}"

    local platform hash
    for platform in "${PLATFORMS[@]}"; do
        echo "  prefetching ${platform}..."
        hash="$(prefetch_hash "${lat}" "${platform}")"
        if [[ -z "${hash}" ]]; then
            die "empty hash for ${platform}"
        fi
        rewrite_hash "${platform}" "${hash}"
    done

    echo "  done. review the diff with: git diff -- ${PACKAGE_FILE}"
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
