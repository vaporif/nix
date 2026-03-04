# Codebase Structure

## Configuration Flow
```
flake.nix (Entry point, thin wiring — inputs + module composition)
    ├── hosts/
    │       ├── common.nix (NixOS module: config.custom.* — user, git, cachix, timezone)
    │       ├── macbook.nix (NixOS module: imports common.nix, sets hostname, system, configPath, sshAgent)
    │       └── nixos.nix (NixOS module: imports common.nix, sets hostname, system, configPath)
    ├── modules/
    │       ├── options.nix (Typed NixOS options: config.custom.* — imported by system + HM)
    │       ├── nix.nix (Shared Nix settings)
    │       └── theme.nix (Shared Stylix theme)
    ├── overlays/ (Custom package overlays)
    ├── pkgs/ (Custom package definitions)
    ├── system/
    │       ├── darwin/ (macOS-only: nix-darwin system config, skhd, SOPS, firewall)
    │       └── nixos/ (NixOS system config: openssh, user account, hardware-configuration.nix)
    └── home/
            ├── common/
            │       ├── default.nix (Imports only ~20 lines)
            │       ├── claude.nix (Claude Code plugins, settings, hooks, commands)
            │       ├── git.nix (Git config, lazygit, gh CLI)
            │       ├── ssh.nix (Hardened SSH client config)
            │       ├── mcp.nix (MCP server configuration — serena, filesystem, github, etc.)
            │       ├── qdrant.nix (Qdrant config.yaml generation)
            │       ├── xdg.nix (xdg.configFile: wezterm, yazi, tidal, procs)
            │       ├── packages.nix (User packages)
            │       ├── shell.nix (Shell programs: zsh, fzf, atuin, etc.)
            │       └── neovim.nix (Neovim via nix-wrapper-modules)
            ├── darwin/ (macOS-specific home config)
            └── linux/ (NixOS-specific: systemd services)
```

## Key Pattern: config.custom.*
All modules consume typed options from `modules/options.nix`:
- `config.custom.user` — username (single source of truth)
- `config.custom.configPath` — repo path (derived from user)
- `config.custom.git.*` — git identity
- `config.custom.hostname`, `config.custom.system`, etc.

`flake.nix` uses inline module functions to read `config.custom.user` for `users.users` and `home-manager.users` — no hardcoded usernames.

## Directory Structure

### Root Level
| File/Dir | Purpose |
|----------|---------|
| `flake.nix` | Main entry point, thin wiring (inputs + module composition) |
| `flake.lock` | Locked versions of all flake inputs |
| `justfile` | Task runner for linting/formatting/update commands |
| `typos.toml` | Typos checker configuration |
| `CLAUDE.md` | Instructions for Claude Code |

### `overlays/` - Custom Package Overlays
| File | Purpose |
|------|---------|
| `default.nix` | Overlay with custom packages (unclog, solidity-lsp, claude_formatter, tidal_script) |

### `hosts/` - Host Configurations (NixOS modules setting config.custom.*)
| File | Purpose |
|------|---------|
| `common.nix` | Shared user config (user, git, cachix, timezone) |
| `macbook.nix` | macOS host (imports common.nix, sets hostname, system, configPath, sshAgent) |
| `nixos.nix` | Linux host (imports common.nix, sets hostname, system, configPath) |

### `modules/` - Shared Modules
| File | Purpose |
|------|---------|
| `options.nix` | Typed NixOS options (config.custom.*) — foundation of config system |
| `nix.nix` | Shared Nix settings |
| `theme.nix` | Shared Stylix theme |

### `system/darwin/` - macOS System Configuration
| File | Purpose |
|------|---------|
| `default.nix` | Nix settings, system defaults, skhd shortcuts, SOPS, firewall, TouchID, Homebrew |

### `home/common/` - Shared Home Manager Configuration
| File | Purpose |
|------|---------|
| `default.nix` | Imports only (~20 lines) + base config (manual, home basics, parry) |
| `claude.nix` | Claude Code plugins, settings, hooks, commands, marketplace |
| `git.nix` | Git config, lazygit, gh CLI, SSH signing |
| `ssh.nix` | Hardened SSH client config |
| `mcp.nix` | MCP server configuration (defines mcpServersConfig option) |
| `qdrant.nix` | Qdrant config.yaml generation |
| `xdg.nix` | xdg.configFile: wezterm, yazi, tidal, procs (@configPath@ substitution) |
| `packages.nix` | User packages + custom derivations |
| `shell.nix` | Zsh, shell tools, aliases |
| `neovim.nix` | Neovim via nix-wrapper-modules (plugins, LSPs, treesitter) |

### `config/` - Application Configurations (Dotfiles)
| Path | Purpose |
|------|---------|
| `nvim/` | Neovim config (init.lua, lua/core/, lua/plugins/, .stylua.toml, selene.toml) |
| `wezterm/` | Terminal config with tmux-like keybindings |
| `yazi/` | File manager config (init.lua, keymap.toml) |
| `karabiner/` | Keyboard customization rules |
| `librewolf/` | Browser configuration overrides |
| `tidal/` | TidalCycles live coding setup |
| `claude/` | Claude Code settings and CLAUDE.md |
| `procs/` | Process viewer configuration |
| `.ssh/` | SSH configuration |
| `direnvrc` | Direnv library functions |

### `pkgs/` - Custom Nix Package Definitions (with passthru.tests)
| File | Purpose |
|------|---------|
| `unclog.nix` | Custom package |
| `nomicfoundation-solidity-language-server.nix` | Solidity LSP |

### `secrets/` - Encrypted Secrets
| File | Purpose |
|------|---------|
| `secrets.yaml` | SOPS-encrypted secrets (API keys, tokens) |

### `scripts/` - Custom Shell Scripts
| File | Purpose |
|---------|---------| 
| `git-bare-clone.sh` | Bare clone with main worktree (installed as `git bclone`) |
| `git-meta.sh` | Worktree config sync via `.meta/` directory (installed as `git meta`) |
| `install-librewolf.sh` | LibreWolf auto-updater |
| `check-flake-age.sh` | Policy check for flake input freshness |
| `setup.sh` | Initial setup script (generates NixOS module format host files) |

### `config/claude/hooks/` - Claude Code Hook Scripts
| File | Purpose |
|---------|---------| 
| `notify.sh` | macOS notification + ntfy.sh phone push when Claude needs input |
| `auto-recall.sh` | Auto-inject Qdrant memories on first prompt per session |
| `check-bash-command.sh` | Security check for bash commands |

### `config/claude-commands/` - Claude Code Custom Commands
| File | Purpose |
|---------|---------| 
| `cleanup.md` | Code review and cleanup of branch changes |
| `commit.md` | Generate commit message from staged changes |
| `docs.md` | Update all documentation after code changes |
| `pr.md` | Generate PR title and description |
| `recall.md` | Search Qdrant memory |
| `remember.md` | Store context in Qdrant |

### Special Files
| File | Purpose |
|------|---------|
| `.sops.yaml` | SOPS encryption configuration |
