# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

Cross-platform Nix configuration for macOS (nix-darwin) and NixOS. Manages system and user configurations declaratively using Nix.

**Hosts:**
- `macbook` — macOS (aarch64-darwin), uses `darwinConfigurations` with nix-darwin + Home Manager
- `nixos` — NixOS (aarch64-linux), uses `nixosConfigurations` with NixOS + Home Manager (shell-only VM)

## Essential Commands

```bash
just switch                   # Apply configuration changes
nix flake update              # Update all flake inputs
sops secrets/secrets.yaml     # Edit encrypted secrets
just check                    # Run all linting checks
just fmt                      # Format all files
git meta <push|pull|diff|init>  # Sync .meta/ configs with worktrees
```

## Linting & Formatting

Run `just` to see all available commands. Key ones:

| Command | Description |
|---------|-------------|
| `just switch` | Apply configuration (auto-detects platform) |
| `just check` | Run all checks (lint + policy) |
| `just check-policy` | Policy checks (freshness, pinning) |
| `just lint-lua` | Selene + stylua for Lua files |
| `just lint-nix` | Flake check + alejandra + statix + deadnix |
| `just fmt` | Format all (Lua + Nix + TOML) |
| `just cache` | Build and push to Cachix |
| `just setup-hooks` | Enable git hooks |

Tools: `selene`, `stylua`, `alejandra`, `statix`, `deadnix`, `typos`, `taplo`, `shellcheck`, `actionlint`, `jaq`, `gitleaks`

## Git Hooks

Enable with `just setup-hooks` or `git config core.hooksPath .githooks`:
- **pre-commit**: Auto-formats code with `just fmt`
- **pre-push**: Runs `just check` then `just cache`

Skip hooks when needed: `git commit --no-verify` or `git push --no-verify`

## Cachix

Binary cache at https://vaporif.cachix.org for faster builds:
- CI automatically pushes builds
- Local: `just cache` to build and push
- Auth: `cachix authtoken <token>` (one-time setup)

## Shell Aliases

- `a` - Claude Code CLI
- `ap` - Claude Code with `--print`
- `ai` - Claude Code with `--dangerously-skip-permissions`
- `ar` - Claude Code with `--resume`
- `g` - Lazygit
- `e` - Neovim
- `t` - Yazi file manager
- `ls` - eza (with hidden files)
- `cat` - bat (syntax highlighting)

## Application Shortcuts (skhd — macOS only)

Uses `hyper` key (caps lock via Karabiner):

| Key | App |
|-----|-----|
| `hyper + r` | Librewolf |
| `hyper + t` | WezTerm |
| `hyper + c` | Claude |
| `hyper + s` | Slack |
| `hyper + b` | Brave |
| `hyper + d` | Discord |
| `hyper + w` | WhatsApp |
| `hyper + m` | Ableton Live |
| `hyper + l` | Signal |
| `hyper + p` | Spotify |

## Architecture

```
flake.nix                    # Entry point; mkHostContext deduplicates per-host setup
├── hosts/
│   ├── common.nix           # Shared user config (name, git, cachix, timezone)
│   ├── macbook.nix          # macOS host overrides (hostname, system, configPath, sshAgent, utmHostIp)
│   └── nixos.nix            # NixOS host overrides (hostname, system, configPath, sshAgent)
├── modules/
│   ├── nix.nix              # Shared Nix settings
│   └── theme.nix            # Shared Stylix theme
├── mcp.nix                  # MCP server configuration (shared)
├── system/
│   ├── darwin/
│   │   └── default.nix      # macOS-only: nix-darwin system config, skhd, SOPS, firewall
│   └── nixos/
│       └── default.nix      # NixOS system config: openssh, user account
├── home/
│   ├── common/              # Shared home-manager config (shell, packages, editor, etc.)
│   ├── darwin/              # macOS-specific home config (Secretive, Claude desktop, UTM SSH)
│   └── linux/               # NixOS-specific home config (systemd services)
├── scripts/
│   ├── setup.sh             # Cross-platform bootstrap script for forks
│   ├── git-bare-clone.sh    # Bare clone with main worktree
│   └── git-meta.sh          # Worktree config sync (.meta/)
├── overlays/                # Custom package overlays
└── pkgs/                    # Custom package definitions
```

### Config Files (dotfiles)

Application configs live in `/config/` and are symlinked via `xdg.configFile`:
- `nvim/` - Neovim (Lua, `recursive = true` so HM can inject `nix-paths.lua` alongside)
- `wezterm/` - Terminal (Lua)
- `yazi/` - File manager
- `karabiner/` - Keyboard remapping (macOS only)

### Path Templating (`configPath`)

Config files that reference the repo path use `userConfig.configPath` (from `hosts/<name>.nix`) instead of hardcoded paths. Two mechanisms:

- **`@configPath@` placeholder** (wezterm, yazi): The config file contains a literal `@configPath@` string. In `home/common/default.nix`, `builtins.replaceStrings` substitutes it with `userConfig.configPath` at build time. Used when the file is loaded via `.text` or `extraConfig` (not `.source`).
- **`nix-paths.lua` module** (nvim): Since `config/nvim/` is symlinked as a recursive directory, individual files can't be templated. Instead, HM generates `nvim/nix-paths.lua` containing `return "<configPath>"`, and `init.lua` does `require("nix-paths")` to get the path at runtime.

## User-Specific Values

Host configs in `hosts/`. Common values in `hosts/common.nix`, per-host overrides in `hosts/<name>.nix`. The `mkHostContext` helper in `flake.nix` builds all derived values (pkgs, LSP packages, serena, MCP config) from a host config, with assertions for required fields.

**Required fields** (in `common.nix` or host override):
- `user` - username
- `hostname` - machine name
- `system` - architecture (`aarch64-darwin` or `aarch64-linux`)
- `configPath` - path to this repo on the host
- `git.*` - git identity and signing key
- `cachix.*` - binary cache config
- `timezone` - system timezone
- `sshAgent` - SSH agent type (`"secretive"` on macOS, `""` on Linux)

**Optional fields** (per-host):
- `utmHostIp` - IP address of UTM VM for SSH config (macOS only)

## MCP Servers

Configured in `mcp.nix`. Available servers:
- **serena** - Semantic code editing (recommended for this repo, has nixd + lua-language-server)
- **filesystem** - File access
- **github** - GitHub operations (uses `gh auth token`)
- **context7** - Library documentation
- **nixos** - NixOS/nix-darwin option search
- **tavily** - Web search
- **deepl** - Translation

## Secrets Management

SOPS with age encryption:
```bash
sops secrets/secrets.yaml              # Edit secrets
cat /run/secrets/<secret-name>         # Access at runtime
```

Key: `~/.config/sops/age/key.txt`

## Claude Code Plugins

Nix-managed plugins from `github:anthropics/claude-code`:
- **feature-dev** - Feature development workflow
- **ralph-wiggum** - Iterative development loops
- **code-review** - PR code review

### Custom Commands

Defined in `config/claude-commands/`, wired via `home/common/default.nix`:
- `/cleanup` - Code review and cleanup of branch changes
- `/commit` - Generate commit message from staged changes
- `/docs` - Update all documentation (CLAUDE.md, Serena, auto memory, Qdrant)
- `/pr` - Generate PR title and description
- `/recall` - Search Qdrant memory
- `/remember` - Store context in Qdrant

## Git Worktree Tools

Custom git subcommands installed via `writeShellScriptBin` in `home/packages.nix`:

- **`git bclone <url>`** - Bare clone with main worktree (`scripts/git-bare-clone.sh`)
- **`git meta <cmd>`** - Sync non-tracked config files between `.meta/` and worktrees (`scripts/git-meta.sh`)
  - `pull` - `.meta/` → worktree (like `git pull`: bring configs to you)
  - `push` - worktree → `.meta/` (like `git push`: send configs to central store)
  - `diff` - show differences between `.meta/` and worktree
  - `init` - create `.meta/` and populate from current worktree
  - File list from `.meta/.files` manifest, defaults: `.envrc`, `.serena/`, `.claude/`, `CLAUDE.md`

## Security & Policy Enforcement

- **Secrets**: SOPS with age encryption (key at `~/.config/sops/age/key.txt`)
- **TouchID**: Enabled for sudo via `security.pam.services.sudo_local.touchIdAuth`
- **Firewall**: Application firewall with stealth mode enabled
- **Umask**: Stricter 077 - new files only readable by owner
- **Sudo timeout**: 1 minute

### CI Policy Checks
- **Vulnerability scanning**: `vulnix` with `vulnix-whitelist.toml`
- **Input freshness**: Warns if flake inputs >30 days old
- **Pinned inputs**: Fails if any inputs are unpinned
- **Secret scanning**: `gitleaks` prevents committing secrets
- **License compliance**: Unfree packages must be allowlisted in `flake.nix`

## Key Implementation Details

- **`mkHostContext`**: Helper in `flake.nix` that builds all per-host derived values (pkgs, LSP packages, serena patch, MCP config) from a host config attrset, eliminating duplication between darwin and linux outputs
- **`serenaSrc`**: Shared patched serena source, extracted to avoid duplication
- **`allowUnfreePredicate`**: Shared unfree allowlist (`spacetimedb`, `claude-code`), applied to both platforms
- **Host assertions**: `mkHostContext` validates required fields (`user`, `hostname`, `system`, `configPath`) at eval time
- **LibreWolf**: Auto-updated via `scripts/install-librewolf.sh` on macOS
- **Qdrant**: Runs as launchd agent on macOS (`home/darwin/`), systemd user service on NixOS (`home/linux/`)
- **External devshell**: Rust tools via `~/.envrc` (run `direnv allow ~` after setup)
- **Theme**: Stylix manages colors/fonts across all apps; shared via `modules/theme.nix`

## Common Tasks

### Adding a Package
1. Edit `home/common/` for shared packages, `home/darwin/` or `home/linux/` for platform-specific, or `system/darwin/`/`system/nixos/` for system packages
2. Run `just switch`

### Adding/Updating Secrets
1. Edit: `sops secrets/secrets.yaml`
2. Define in nix: `sops.secrets.my-secret = { };` (in `system/security.nix`)
3. Access at runtime: `/run/secrets/my-secret`

### Adding MCP Servers
1. Edit `mcp.nix`
2. Follow existing patterns (see `programs` or `settings.servers`)
3. Apply and restart Claude app

### Modifying Shell Aliases
1. Edit shell config in `home/common/` → `shellAliases` section
2. Apply with `just switch`
