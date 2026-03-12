# List available recipes
default:
    @just --list

# Run all checks
check: lint-lua lint-nix lint-json lint-toml lint-shell lint-actions check-typos check-pinned

# Lint nvim lua with selene
lint-lua:
    cd config/nvim && selene lua after init.lua
    stylua --check config/

# Format lua files
fmt-lua:
    stylua config/

# Lint nix files
lint-nix:
    nix flake check
    alejandra --check .
    statix check
    deadnix --fail

# Format nix files
fmt-nix:
    alejandra .

# Validate JSON configs
lint-json:
    jq empty config/karabiner/karabiner.json

# Lint TOML files
lint-toml:
    taplo check

# Format TOML files
fmt-toml:
    taplo fmt

# Lint shell scripts
lint-shell:
    shellcheck -S style -o all scripts/*.sh

# Lint GitHub Actions
lint-actions:
    actionlint

# Check for typos
check-typos:
    typos

# Scan for vulnerabilities (with whitelist)
check-vulns:
    vulnix --system --whitelist vulnix-whitelist.toml

# Verify inputs are pinned
check-pinned:
    @echo "Checking all inputs are pinned..."
    @! grep -q '"type": "indirect"' flake.lock && echo "All inputs properly pinned."

# Format all
fmt: fmt-lua fmt-nix fmt-toml

# Apply configuration with pretty output
switch:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ "$(uname)" == "Darwin" ]]; then
        hostname=$(scutil --get LocalHostName)
        nom build ".#darwinConfigurations.${hostname}.system"
        [[ -e /run/current-system ]] && nvd diff /run/current-system ./result || true
        sudo -H nix-env --profile /nix/var/nix/profiles/system --set ./result
        sudo ./result/activate
    else
        hostname=$(hostname -s)
        nom build ".#nixosConfigurations.${hostname}.config.system.build.toplevel"
        [[ -e /run/current-system ]] && nvd diff /run/current-system ./result || true
        sudo -H nix-env --profile /nix/var/nix/profiles/system --set ./result
        sudo ./result/bin/switch-to-configuration switch
    fi

# Update neovim plugins
lazy-update:
    nvim --headless "+Lazy! update" +qa

# Set up git hooks
setup-hooks:
    git config core.hooksPath .githooks

# Regenerate docs/keymaps.md from source files
keymaps:
    nvim -l scripts/dump-keymaps.lua config/nvim/lua > docs/keymaps.md

# Build and push to cachix
cache:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ "$(uname)" == "Darwin" ]]; then
        hostname=$(scutil --get LocalHostName)
        cachix_name=$(nix eval --raw ".#darwinConfigurations.${hostname}.config.custom.cachix.name")
        nix build ".#darwinConfigurations.${hostname}.system"
    else
        hostname=$(hostname -s)
        cachix_name=$(nix eval --raw ".#nixosConfigurations.${hostname}.config.custom.cachix.name")
        nix build ".#nixosConfigurations.${hostname}.config.system.build.toplevel"
    fi
    [[ -n "$cachix_name" ]] && cachix push "$cachix_name" ./result

# Delete generations older than X days and garbage collect (e.g., just gc 30d)
gc age:
    sudo nix-collect-garbage --delete-older-than {{ age }}
    nix-collect-garbage --delete-older-than {{ age }}
