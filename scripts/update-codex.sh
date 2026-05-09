#!/usr/bin/env bash
# Update vendored codex package to the latest openai/codex `rust-v*` release.
#
# Sources of truth:
#   - version: GitHub releases — latest tag prefixed `rust-v`
#   - binary:  https://github.com/openai/codex/releases/download/rust-v<v>/codex-<platform>.tar.gz
#
# Hashes are computed locally via nix-prefetch-url; trust surface is GitHub
# release artifacts plus the GitHub release metadata for version discovery.
#
# Usage:
#   update-codex.sh           # bump pkgs/codex/package.nix in place
#   update-codex.sh --check   # exit 1 (with hint on stderr) if a newer version exists

set -euo pipefail

readonly GH_REPO="openai/codex"
readonly RELEASE_BASE="https://github.com/${GH_REPO}/releases/download"
readonly PLATFORMS=(
    "aarch64-apple-darwin"
    "x86_64-apple-darwin"
    "x86_64-unknown-linux-musl"
    "aarch64-unknown-linux-musl"
)

REPO_ROOT="$(git -C "$(dirname -- "$0")" rev-parse --show-toplevel)"
readonly REPO_ROOT
readonly PACKAGE_FILE="${REPO_ROOT}/pkgs/codex/package.nix"

die() {
    echo "error: $*" >&2
    exit 2
}

current_version() {
    sed -n 's/^[[:space:]]*version = "\([^"]*\)";.*/\1/p' "${PACKAGE_FILE}" | head -n1
}

# Latest stable tag matching `rust-v*`, ignoring drafts and pre-releases
# (alpha/beta/rc). We list rather than use `gh release view` so an unrelated
# newer non-rust-v tag doesn't shadow ours.
latest_version() {
    gh release list --repo "${GH_REPO}" --limit 30 --json tagName,isDraft,isPrerelease \
        --jq '[.[] | select(.isDraft | not) | select(.isPrerelease | not) | select(.tagName | startswith("rust-v")) | .tagName] | first' \
        | sed 's/^rust-v//'
}

prefetch_hash() {
    local version="$1" platform="$2"
    nix-prefetch-url --type sha256 \
        "${RELEASE_BASE}/rust-v${version}/codex-${platform}.tar.gz" 2>/dev/null \
        | tail -n1
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
        echo "codex up to date (${cur})"
        return 0
    fi
    echo "codex ${lat} available (currently ${cur}) — run \`just llm-update\`" >&2
    return 1
}

do_update() {
    [[ -f "${PACKAGE_FILE}" ]] || die "missing ${PACKAGE_FILE}"
    command -v nix-prefetch-url >/dev/null || die "nix-prefetch-url not in PATH"
    command -v gh >/dev/null || die "gh not in PATH"

    local cur lat
    cur="$(current_version)"
    lat="$(latest_version)"
    if [[ -z "${cur}" || -z "${lat}" ]]; then
        die "could not read current (${cur}) or latest (${lat}) version"
    fi

    if [[ "${cur}" == "${lat}" ]]; then
        echo "codex already at ${cur}"
        return 0
    fi

    echo "codex: ${cur} -> ${lat}"
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
