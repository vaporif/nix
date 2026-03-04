# Codebase Structure

## Configuration Flow
```
flake.nix (Entry point, outputs for both platforms)
    ├── hosts/
    │       ├── common.nix (Shared: user, git, cachix, timezone)
    │       ├── macbook.nix (macOS host overrides)
    │       └── nixos.nix (Linux host overrides)
    ├── modules/
    │       ├── nix.nix (Shared Nix settings)
    │       └── theme.nix (Shared Stylix theme, Linux standalone)
    ├── overlays/ (Custom package overlays)
    ├── pkgs/ (Custom package definitions)
    ├── system/
    │       ├── darwin/ (macOS-only: nix-darwin system config, skhd, SOPS, firewall)
    │       └── nixos/ (NixOS system config: openssh, user account, hardware-configuration.nix)
    └── home/
            ├── common/ (Shared home-manager: shell, packages, editor, etc.)
            ├── darwin/ (macOS-specific home config)
            └── linux/ (NixOS-specific: systemd services)
```

## Directory Structure

### Root Level
| File/Dir | Purpose |
|----------|---------|
| `flake.nix` | Main entry point, defines inputs and outputs for both platforms |
| `flake.lock` | Locked versions of all flake inputs |
| `justfile` | Task runner for linting/formatting/update commands |
| `typos.toml` | Typos checker configuration |
| `mcp.nix` | MCP server configuration |
| `CLAUDE.md` | Instructions for Claude Code |

### `overlays/` - Custom Package Overlays
| File | Purpose |
|------|---------|
| `default.nix` | Overlay with custom packages (unclog, solidity-lsp, claude_formatter, tidal_script) |

### `hosts/` - Host Configurations
| File | Purpose |
|------|---------|
| `common.nix` | Shared user config (name, git, cachix, timezone) |
| `macbook.nix` | macOS host overrides (hostname, system, configPath, sshAgent) |
| `nixos.nix` | Linux host overrides |

### `modules/` - Shared Modules
| File | Purpose |
|------|---------|
| `nix.nix` | Shared Nix settings |
| `theme.nix` | Shared Stylix theme (used standalone on Linux) |

### `system/darwin/` - macOS System Configuration
| File | Purpose |
|------|---------|
| `default.nix` | Nix settings, system defaults, skhd shortcuts, SOPS, firewall, TouchID, Homebrew |

### `home/` - Home Manager Configuration
| Dir | Purpose |
|------|---------|
| `common/` | Shared config (shell, packages, editor, neovim.nix for nix-wrapper-modules) |
| `darwin/` | macOS-specific home config |
| `linux/` | NixOS-specific: systemd services (Qdrant) |

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
| `setup.sh` | Initial setup script |

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
