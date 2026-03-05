#!/bin/bash

# LibreWolf DMG installer script for macOS ARM64
# This script downloads and installs the latest LibreWolf from Codeberg

set -e
shopt -s inherit_errexit

# Ensure Nix paths are available
export PATH="/etc/profiles/per-user/${USER}/bin:/run/current-system/sw/bin:${PATH}"

# GPG wrapper - runs from nixpkgs stable without permanent install
# --no-write-lock-file avoids lock issues during system activation
gpg() {
    nix shell nixpkgs/nixos-25.05#gnupg --no-write-lock-file -c gpg --batch --no-tty "$@"
}

# Configuration
CODEBERG_API="https://codeberg.org/api/v1"
CODEBERG_PACKAGES="https://codeberg.org/api/packages/librewolf/generic/librewolf"
TEMP_DIR="/tmp/librewolf-install"
APP_NAME="LibreWolf.app"
INSTALL_PATH="/Applications"

# GPG verification
LIBREWOLF_GPG_KEY="40339DD82B12EF16"
GPG_KEY_URL="https://repo.librewolf.net/pubkey.gpg"

# Deploy Nix-generated policies into LibreWolf app bundle
deploy_policies() {
    local POLICIES_SRC="${HOME}/.librewolf/policies.json"
    local POLICIES_DST="${INSTALL_PATH}/${APP_NAME}/Contents/Resources/distribution/policies.json"
    if [[ -f "${POLICIES_SRC}" ]]; then
        echo "Deploying custom policies.json..."
        mkdir -p "$(dirname "${POLICIES_DST}")"
        cp "${POLICIES_SRC}" "${POLICIES_DST}"
    fi
}

# Function to get latest version
get_latest_version() {
    local api_response grep_result sed_result sorted_result
    api_response=$(curl -s "${CODEBERG_API}/packages/librewolf")
    grep_result=$(echo "${api_response}" | grep -o '"version":"[0-9][0-9]*\.[0-9][^"]*"' || true)
    # Extract version numbers from "version":"X.Y.Z" format
    sed_result="${grep_result//\"version\":\"/}"
    sed_result="${sed_result//\"/}"
    sorted_result=$(echo "${sed_result}" | sort -V)
    echo "${sorted_result}" | tail -1
}

# Function to get installed version
get_installed_version() {
    if [[ -d "${INSTALL_PATH}/${APP_NAME}" ]]; then
        /usr/bin/defaults read "${INSTALL_PATH}/${APP_NAME}/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo ""
    else
        echo ""
    fi
}

# Function to download and install
install_librewolf() {
    local VERSION INSTALLED_VERSION DMG_URL SIG_URL MOUNT_POINT VOLUME_PATH

    # Check if LibreWolf is running
    if pgrep -i "librewolf" > /dev/null; then
        echo "LibreWolf is currently running. Skipping update."
        hdiutil detach "${MOUNT_POINT}" -quiet 2>/dev/null || true
        rm -rf "${TEMP_DIR}"
        exit 0
    fi
    echo "Fetching latest LibreWolf version..."
    VERSION=$(get_latest_version)

    if [[ -z "${VERSION}" ]]; then
        echo "Error: Could not determine latest version"
        exit 1
    fi

    echo "Latest version: ${VERSION}"

    # Check installed version
    INSTALLED_VERSION=$(get_installed_version)
    if [[ -n "${INSTALLED_VERSION}" ]]; then
        echo "Installed version: ${INSTALLED_VERSION}"
        if [[ "${INSTALLED_VERSION}" = "${VERSION}" ]]; then
            echo "LibreWolf is already up to date. Skipping installation."
            deploy_policies
            exit 0
        fi
    else
        echo "LibreWolf not currently installed."
    fi

    # Construct download URL for ARM64
    DMG_URL="${CODEBERG_PACKAGES}/${VERSION}/librewolf-${VERSION}-macos-arm64-package.dmg"

    echo "Downloading LibreWolf ${VERSION} for ARM64..."

    # Create temp directory
    mkdir -p "${TEMP_DIR}"

    # Download DMG
    curl -L -o "${TEMP_DIR}/librewolf.dmg" "${DMG_URL}"

    # Download signature file
    SIG_URL="${CODEBERG_PACKAGES}/${VERSION}/librewolf-${VERSION}-macos-arm64-package.dmg.sig"
    echo "Downloading GPG signature..."
    curl -L -o "${TEMP_DIR}/librewolf.dmg.sig" "${SIG_URL}"

    # Import LibreWolf GPG key if not already present
    echo "Checking for GPG key ..."
    local key_exists=0
    # shellcheck disable=SC2310 # intentionally capturing exit code
    gpg --list-keys "${LIBREWOLF_GPG_KEY}" &>/dev/null || key_exists=$?
    if [[ ${key_exists} -ne 0 ]]; then
        echo "Importing LibreWolf GPG key..."
        curl -sL "${GPG_KEY_URL}" -o "${TEMP_DIR}/librewolf-key.gpg"
        echo "Running GPG import..."
        gpg --import "${TEMP_DIR}/librewolf-key.gpg"
    fi
    echo "GPG key ready."

    # Verify GPG signature
    echo "Verifying GPG signature..."
    local gpg_output
    # shellcheck disable=SC2310 # intentionally capturing output regardless of exit code
    gpg_output=$(gpg --verify "${TEMP_DIR}/librewolf.dmg.sig" "${TEMP_DIR}/librewolf.dmg" 2>&1 || true)
    if ! echo "${gpg_output}" | grep -q "Good signature"; then
        echo "ERROR: GPG signature verification failed!"
        rm -rf "${TEMP_DIR}"
        exit 1
    fi
    echo "GPG signature verified."

    # Mount DMG
    echo "Mounting DMG..."
    hdiutil attach "${TEMP_DIR}/librewolf.dmg" -nobrowse -quiet

    # Find mount point
    local hdiutil_output grep_output awk_output
    hdiutil_output=$(hdiutil info)
    grep_output=$(echo "${hdiutil_output}" | grep "LibreWolf" || true)
    awk_output=$(echo "${grep_output}" | awk '{print $1}')
    MOUNT_POINT=$(echo "${awk_output}" | head -1)
    VOLUME_PATH="/Volumes/LibreWolf"


    # Remove old installation if exists
    if [[ -d "${INSTALL_PATH}/${APP_NAME}" ]]; then
        echo "Removing old LibreWolf installation..."
        rm -rf "${INSTALL_PATH:?}/${APP_NAME:?}"
    fi

    # Copy app to Applications
    echo "Installing LibreWolf to ${INSTALL_PATH}..."
    cp -R "${VOLUME_PATH}/${APP_NAME}" "${INSTALL_PATH}/"

    # Deploy policies into freshly installed app
    deploy_policies

    # Unmount DMG
    echo "Cleaning up..."
    hdiutil detach "${MOUNT_POINT}" -quiet

    # Clean up temp files
    rm -rf "${TEMP_DIR}"

    # Remove quarantine attribute (since it's unsigned)
    xattr -r -d com.apple.quarantine "${INSTALL_PATH}/${APP_NAME}" 2>/dev/null || true

    echo "LibreWolf ${VERSION} installed successfully!"
}

# Check if running on ARM64
arch=$(uname -m)
if [[ "${arch}" != "arm64" ]]; then
    echo "Warning: This script is intended for ARM64 Macs"
fi

# Main execution
install_librewolf
