# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

Cross-platform Nix configuration for macOS (nix-darwin) and NixOS. Manages system and user configurations declaratively using Nix.

**Hosts:**
- `burnedapple` — macOS (aarch64-darwin), uses `darwinConfigurations` with nix-darwin + Home Manager
- `nixos` — NixOS (aarch64-linux), uses `nixosConfigurations` with NixOS + Home Manager (shell-only VM)

## Essential Commands

```bash
just switch                   # Apply configuration changes
just check                    # Run all linting checks
just fmt                      # Format all files
nix flake update              # Update all flake inputs
sops secrets/secrets.yaml     # Edit encrypted secrets
git meta <push|pull|diff|init>  # Sync .meta/ configs with worktrees
```

Tools: `selene`, `stylua`, `alejandra`, `statix`, `deadnix`, `typos`, `taplo`, `shellcheck`, `actionlint`, `jaq`, `gitleaks`

## Architecture

```
flake.nix                    # Entry point (inputs + module composition)
├── hosts/                   # Host configs: common.nix, macbook.nix, nixos.nix
├── modules/                 # Shared: options.nix, nix.nix, theme.nix
├── system/{darwin,nixos}/   # Platform system configs
├── home/{common,darwin,linux}/ # Home Manager configs
├── claude/                  # Everything Claude: home/, security/, overrides/, package.nix, update.sh, statusline.sh, direnv-rules.sh
├── config/                  # Dotfiles: nvim/, wezterm/, yazi/, karabiner/
├── assistants/              # Shared assistant content (rules/skills/agents/commands consumed by claude + codex)
├── scripts/                 # Helper scripts (setup, git-meta, git-bare-clone, keymaps, codex)
├── tests/                   # Integration tests (claude-security.nix, claude-settings.nix, codex.nix)
├── overlays/                # Custom package overlays
├── patches/                 # Custom patches for packages
└── pkgs/                    # Custom package definitions
```

### Path Templating (`configPath`)

- **`@configPath@` placeholder** (wezterm, yazi): Substituted via `builtins.replaceStrings` in `home/common/xdg.nix` at build time.
- **`nix-info` module** (nvim): nix-wrapper-modules injects `config_directory`. `init.lua` reads `_G.nixInfo.settings.config_directory`.

## Key Patterns

- **`config.custom.*`**: Typed NixOS options in `modules/options.nix`. All modules consume these instead of `extraSpecialArgs`. Options defined in `hosts/common.nix`, overridden per-host.
- **lze plugin loading**: Uses `on_require`, `dep_of`, `on_plugin`. Does NOT have a `dep` field. Library deps in `config/nvim/lua/plugins/deps.lua`.
- **`allowUnfreePredicate`**: Shared unfree allowlist in `flake.nix`, applied to both platforms.
- **Claude consolidation**: All Claude code lives under `claude/` — `claude/home.nix` is the HM entry, `claude/security/` is the security module generating `settingsFragment` (hooks + permissions), `claude/home/settings.nix` merges it into `~/.claude/settings.json`, `claude/package.nix` is the vendored binary, `claude/overrides/` holds CLAUDE.md and agent overrides.
- **Git worktree tools**: `git bclone` (bare clone) and `git meta` (sync .meta/ configs) installed via `home/packages.nix`.
- **Claude rules (direnv)**: Language rules stored in `~/.config/claude-rules/` (nix-managed). Use `use claude_rules` in `.envrc` to symlink relevant rules into project-local `.claude/rules/`. Auto-detects languages when called without args. Explicit: `use claude_rules go nix`. See `claude/direnv-rules.sh`.

## Secrets Management

SOPS with age encryption. Key: `~/.config/sops/age/key.txt`
```bash
sops secrets/secrets.yaml              # Edit secrets
# Define in nix: sops.secrets.my-secret = { };
# Access at runtime: /run/secrets/<secret-name>
```
