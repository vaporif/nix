# Project Overview

## Purpose
This is a **cross-platform Nix configuration** for macOS (nix-darwin) and NixOS that manages system-level and user-level configurations declaratively. It provides a complete development environment setup including:
- System preferences and settings
- Development tools and language servers
- Application configurations (Neovim, WezTerm, Yazi, etc.)
- MCP (Model Context Protocol) server integrations for AI capabilities
- Secrets management via SOPS (macOS)
- Consistent theming via Stylix

## Tech Stack
- **Configuration Language**: Nix expression language
- **System Management**: nix-darwin (macOS), NixOS (Linux)
- **User Environment**: Home Manager (as module on both platforms)
- **Secrets**: SOPS with age encryption
- **Theming**: Stylix (Earthtone Light theme)
- **Platforms**: macOS (aarch64-darwin), NixOS (aarch64-linux)

## Key Dependencies (Flake Inputs)
- `nixpkgs` (unstable channel)
- `nix-darwin`
- `home-manager`
- `sops-nix`
- `stylix`
- `mcp-servers-nix` - MCP server configurations
- `nix-devshells` - External Rust devshell (referenced in ~/.envrc)
- `wrappers` (nix-wrapper-modules) - Neovim plugin/LSP management via Nix
- `vim-tidal-lua` - TidalCycles Neovim plugin (Lua rewrite)

## Configuration Pattern
All user-specific values are typed NixOS options in `modules/options.nix` under `config.custom.*`. Modules consume these directly — no `extraSpecialArgs` passthrough. `flake.nix` is thin wiring only.

## Hosts
- **macbook** — macOS (aarch64-darwin), `darwinConfigurations`, configured via `hosts/macbook.nix` → `hosts/common.nix`
- **nixos** — NixOS (aarch64-linux), `nixosConfigurations`, configured via `hosts/nixos.nix` → `hosts/common.nix` (shell-only VM)
- **nixos** — NixOS (aarch64-linux), `nixosConfigurations`, user `vaporif` (shell-only VM)
