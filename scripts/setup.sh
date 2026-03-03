#!/usr/bin/env bash
set -e
shopt -s inherit_errexit

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Nix Configuration Setup ===${NC}"
echo ""

# Must be run from repo root
if [[ ! -f "flake.nix" ]]; then
    echo -e "${RED}Error: Must be run from the repository root (flake.nix not found).${NC}"
    exit 1
fi

# Check if nix is installed
if ! command -v nix &> /dev/null; then
    echo -e "${RED}Error: Nix is not installed.${NC}"
    echo "Install with: curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install"
    exit 1
fi

# Check if age-keygen is available (needed for SOPS key generation)
if ! command -v age-keygen &> /dev/null; then
    echo -e "${RED}Error: age-keygen is not installed (needed for secrets encryption).${NC}"
    echo "Install with: nix profile install nixpkgs#age"
    exit 1
fi

# Warn if already configured
if [[ -f "hosts/common.nix" ]] && grep -q "signingKey" hosts/common.nix; then
    echo -e "${YELLOW}Warning: hosts/common.nix already contains configuration.${NC}"
    read -rp "Overwrite existing config? [y/N]: " CONFIRM
    if [[ "${CONFIRM}" != "y" && "${CONFIRM}" != "Y" ]]; then
        echo "Aborted."
        exit 0
    fi
    echo ""
fi

# Detect platform
OS=$(uname -s)
ARCH=$(uname -m)
CURRENT_USER="${USER}"

if [[ "${OS}" == "Darwin" ]]; then
    CURRENT_HOSTNAME=$(scutil --get LocalHostName 2>/dev/null || hostname -s)
    if [[ "${ARCH}" == "arm64" ]]; then
        NIX_SYSTEM="aarch64-darwin"
    else
        NIX_SYSTEM="x86_64-darwin"
    fi
    HOST_FILE="hosts/macbook.nix"
    PLATFORM="macOS"
else
    CURRENT_HOSTNAME=$(hostname -s)
    if [[ "${ARCH}" == "aarch64" ]]; then
        NIX_SYSTEM="aarch64-linux"
    else
        NIX_SYSTEM="x86_64-linux"
    fi
    HOST_FILE="hosts/nixos.nix"
    PLATFORM="Linux"
fi

echo "Detected configuration:"
echo "  Platform: ${PLATFORM}"
echo "  Username: ${CURRENT_USER}"
echo "  Hostname: ${CURRENT_HOSTNAME}"
echo "  System:   ${NIX_SYSTEM}"
echo ""

# Prompt for confirmation or custom values
read -rp "Username [${CURRENT_USER}]: " INPUT_USER
USERNAME="${INPUT_USER:-${CURRENT_USER}}"

# Validate username (used as YAML anchor in .sops.yaml and Nix identifier)
if [[ ! "${USERNAME}" =~ ^[a-zA-Z_][a-zA-Z0-9_-]*$ ]]; then
    echo -e "${RED}Error: Username '${USERNAME}' contains invalid characters.${NC}"
    echo "Only letters, digits, underscores, and hyphens are allowed (must start with letter or underscore)."
    exit 1
fi

read -rp "Hostname [${CURRENT_HOSTNAME}]: " INPUT_HOST
HOSTNAME="${INPUT_HOST:-${CURRENT_HOSTNAME}}"

read -rp "Git name: " GIT_NAME
read -rp "Git email: " GIT_EMAIL
read -rp "Timezone [UTC]: " INPUT_TZ
TIMEZONE="${INPUT_TZ:-UTC}"

if [[ "${OS}" == "Darwin" ]]; then
    read -rp "SSH agent (secretive/default) [default]: " INPUT_SSH
    SSH_AGENT="${INPUT_SSH:-}"
else
    SSH_AGENT=""
fi

echo ""
echo -e "${YELLOW}Updating hosts/common.nix and ${HOST_FILE}...${NC}"

# Get current directory for configPath
CONFIG_PATH=$(pwd)

# Update hosts/common.nix
cat > hosts/common.nix << EOF
# Shared config inherited by all hosts.
# Per-host files (macbook.nix, nixos.nix) import this and add:
#   hostname  (string)  - machine name, used as flake output key
#   system    (string)  - "aarch64-darwin" | "aarch64-linux" | "x86_64-darwin" | "x86_64-linux"
#   configPath (string) - absolute path to this repo on the host
#   sshAgent  (string)  - "secretive" for macOS Secretive.app, "" otherwise
# Optional per-host fields:
#   utmHostIp (string)  - IP of UTM VM for SSH config (macOS only)
{
  user = "${USERNAME}";

  git = {
    name = "${GIT_NAME}";
    email = "${GIT_EMAIL}";
    signingKey = "";
  };

  # Cachix binary cache (optional, set to empty strings if not using)
  # Create your own at https://app.cachix.org
  cachix = {
    name = "";
    publicKey = "";
  };

  timezone = "${TIMEZONE}";
}
EOF

# Update host-specific file
cat > "${HOST_FILE}" << EOF
let
  common = import ./common.nix;
in
  common
  // {
    hostname = "${HOSTNAME}";
    system = "${NIX_SYSTEM}";
    configPath = "${CONFIG_PATH}";
    sshAgent = "${SSH_AGENT}";
  }
EOF

echo -e "${GREEN}hosts/common.nix and ${HOST_FILE} updated${NC}"

# Setup age key for SOPS
AGE_KEY_DIR="${HOME}/.config/sops/age"
AGE_KEY_FILE="${AGE_KEY_DIR}/key.txt"

if [[ ! -f "${AGE_KEY_FILE}" ]]; then
    echo ""
    echo -e "${YELLOW}Generating age key for secrets...${NC}"
    mkdir -p "${AGE_KEY_DIR}"
    keygen_output=$(age-keygen -o "${AGE_KEY_FILE}" 2>&1)
    echo "${keygen_output}"
    chmod 600 "${AGE_KEY_FILE}"

    # Extract public key
    grep_output=$(echo "${keygen_output}" | grep "public key:" || true)
    AGE_PUBLIC_KEY=$(echo "${grep_output}" | awk '{print $3}')

    echo -e "${GREEN}Age key generated at ${AGE_KEY_FILE}${NC}"
    echo ""
    echo -e "${YELLOW}Your public key: ${AGE_PUBLIC_KEY}${NC}"
else
    echo ""
    echo -e "${GREEN}Age key already exists at ${AGE_KEY_FILE}${NC}"
    AGE_PUBLIC_KEY=$(age-keygen -y "${AGE_KEY_FILE}")
    echo "Public key: ${AGE_PUBLIC_KEY}"
fi

# Update .sops.yaml
echo ""
echo -e "${YELLOW}Updating .sops.yaml...${NC}"
cat > .sops.yaml << EOF
keys:
  - &${USERNAME} ${AGE_PUBLIC_KEY}
creation_rules:
  - path_regex: secrets/[^/]+\.(yaml|json|env|ini)$
    key_groups:
    - age:
      - *${USERNAME}
EOF
echo -e "${GREEN}.sops.yaml updated${NC}"

# Create secrets template if secrets don't exist
if [[ ! -f "secrets/secrets.yaml" ]]; then
    echo ""
    echo -e "${YELLOW}Creating secrets template...${NC}"
    mkdir -p secrets

    # Create unencrypted template
    cat > secrets/secrets.yaml.template << 'EOF'
# Template for secrets.yaml
# Copy this to secrets.yaml and encrypt with: sops -e -i secrets/secrets.yaml
#
# Example secrets (replace with your actual secrets):
github_token: "ghp_xxxxxxxxxxxxxxxxxxxx"
api_key: "your-api-key-here"
EOF

    echo -e "${GREEN}Template created at secrets/secrets.yaml.template${NC}"
    echo "Edit and encrypt with: sops secrets/secrets.yaml"
fi

# Update hostname references in CI/build files
echo ""
echo -e "${YELLOW}Updating hostname references...${NC}"
if [[ "${OS}" == "Darwin" ]]; then
    sed -i "s/MacBook-Pro/${HOSTNAME}/g" .github/workflows/check.yml 2>/dev/null || true
else
    sed -i "s/nixos/${HOSTNAME}/g" .github/workflows/check.yml 2>/dev/null || true
fi

echo ""
echo -e "${GREEN}=== Setup Complete ===${NC}"
echo ""
echo "Next steps:"
echo "  1. Review hosts/common.nix and ${HOST_FILE} for any additional changes"
echo "  2. Create and encrypt secrets: sops secrets/secrets.yaml"
echo "  3. Run: just switch"
echo ""
echo "Optional:"
echo "  - Set up Cachix: https://app.cachix.org"
if [[ "${OS}" == "Darwin" ]]; then
    echo "  - Set up SSH signing key in hosts/common.nix (uses Secretive)"
fi
