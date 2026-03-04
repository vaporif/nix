# Implementation Details

This document describes what's implemented in this nix-darwin configuration and how each component is structured.

---

## 1. Configuration Architecture

### Module Hierarchy
```
modules/options.nix (typed NixOS options: config.custom.*)
hosts/common.nix (NixOS module: sets config.custom.user, git, cachix, timezone)
hosts/macbook.nix (NixOS module: imports common.nix, sets hostname, system, configPath, sshAgent)
hosts/nixos.nix (NixOS module: imports common.nix, sets hostname, system, configPath)
flake.nix (thin wiring — inputs + module composition, no business logic)
├── Inputs: nixpkgs, nix-darwin, home-manager, sops-nix, stylix, mcp-servers-nix
├── Overlays: localPackages (custom packages), allowUnfreePredicate
│
├── system/
│   ├── darwin/ (macOS system configuration)
│   │   ├── default.nix - imports options.nix, nix.nix, theme.nix, uses config.custom.*
│   │   ├── security.nix - SOPS secrets, firewall, TouchID
│   │   └── homebrew.nix - Homebrew casks
│   └── nixos/ (NixOS system configuration)
│       └── default.nix - imports options.nix, nix.nix, theme.nix, uses config.custom.*
│
├── home/ (Home Manager user configuration)
│   ├── common/
│   │   ├── default.nix - Imports only (~20 lines)
│   │   ├── claude.nix - Claude Code plugins, settings, hooks, commands
│   │   ├── git.nix - Git, lazygit, gh CLI
│   │   ├── ssh.nix - Hardened SSH client
│   │   ├── mcp.nix - MCP server configuration
│   │   ├── qdrant.nix - Qdrant config
│   │   ├── xdg.nix - xdg.configFile (wezterm, yazi, tidal, procs)
│   │   ├── packages.nix - User packages
│   │   ├── shell.nix - Shell programs
│   │   └── neovim.nix - Neovim via nix-wrapper-modules
│   ├── darwin/ - macOS-specific home config
│   └── linux/ - NixOS-specific home config
│
└── config/ (Application dotfiles)
    ├── nvim/ - Neovim configuration
    ├── wezterm/ - Terminal configuration
    ├── yazi/ - File manager configuration
    ├── karabiner/ - Keyboard customization
    ├── claude/ - Claude Code settings
    └── ...
```

### Key Design Pattern
- **config.custom.* options**: All user-specific values defined as typed NixOS options in `modules/options.nix`, consumed via `config.custom.*` in all modules
- **Single source of truth**: Change `user` in `hosts/common.nix` and all paths, configs, and references update automatically
- **Thin flake.nix**: Pure wiring — no business logic, no helpers. Uses inline module functions to read `config.custom.user` for `users.users` and `home-manager.users`
- **Separation of concerns**: System-level config in `system/`, user-level in `home/`, dotfiles in `config/`
- **Focused modules**: Each `home/common/*.nix` file handles one concern
- **XDG compliance**: Configs placed via `xdg.configFile`
- **Declarative dotfiles**: All configs managed through Nix, not manually

---

## 2. Theming System (Stylix)

**Location**: `system/theme.nix`

**Implementation**:
- Custom Everforest Light base16 color scheme
- Font: Hack Nerd Font Mono (sizes: terminal=16, apps=12, desktop=10)
- Polarity: light theme
- Auto-applies to all supported applications

```nix
stylix = {
  enable = true;
  base16Scheme = { ... };  # 16 custom colors
  fonts.monospace = { package = pkgs.nerd-fonts.hack; name = "Hack Nerd Font Mono"; };
  polarity = "light";
};
```

---

## 3. Secrets Management (SOPS)

**Location**: `system/security.nix`, `secrets/secrets.yaml`

**Implementation**:
- Encryption: Age (key at `~/.config/sops/age/key.txt`)
- Secrets stored in `secrets/secrets.yaml` (encrypted YAML)
- Decrypted at runtime to `/run/secrets/<name>`
- Exposed to shell via `initContent` in zsh config

**Managed Secrets**:
- `openrouter-key` - AI API access
- `tavily-key` - Search API
- `youtube-key` - YouTube API

**Usage pattern**:
```nix
sops.secrets.openrouter-key = { owner = "vaporif"; mode = "0400"; };
# Access in shell: $(cat /run/secrets/openrouter-key)
```

---

## 4. MCP Servers Integration

**Location**: `home/common/mcp.nix`

**Implementation**:
- Uses `mcp-servers-nix` flake for declarative MCP config
- Config generated in `home/common/mcp.nix` via `mcp-servers-nix.lib.mkConfig`
- Defines `options.custom.mcpServersConfig` (read-only) for other modules to consume
- LSP packages and serena patch defined locally in `mcp.nix`
- Output written to multiple locations:
  - `/Library/Application Support/ClaudeCode/managed-mcp.json` (via HM activation in `home/darwin/`)
  - `~/Library/Application Support/Claude/claude_desktop_config.json` (via `home/darwin/`)
  - `~/.config/mcphub/servers.json` (via `home/common/mcp.nix`)

**Enabled Servers** (configured in `mcp.nix`):
| Server | Purpose | Config |
|--------|---------|--------|
| filesystem | File access | Multiple paths including ~/Documents, /private/etc/nix-darwin |
| git | Git operations | default |
| sequential-thinking | AI reasoning | default |
| time | Time utilities | local-timezone: Europe/Lisbon |
| context7 | Library documentation | default |
| memory | Persistent memory | default |
| serena | Code intelligence | extraPackages: LSPs (rust-analyzer, gopls, nixd, lua-language-server, etc.) |
| github | GitHub operations | Uses `gh auth token` |
| tavily | Web search | API key from SOPS |
| deepl | Translation | API key from SOPS |
| nixos | NixOS/nix-darwin options | default |

---

## 5. Neovim Configuration

**Location**: `config/nvim/` (Lua configs), `home/common/neovim.nix` (Nix plugin management)

### Plugin Management
Neovim uses **nix-wrapper-modules** (BirdeeHub) instead of lazy.nvim:
- Plugins installed by Nix into `start/` (eager) or `opt/` (lazy-loaded by lze)
- `home/common/neovim.nix` defines all plugins, treesitter grammars, LSPs, and extra packages
- Runtime lazy-loading handled by `lze` plugin manager
- Update plugins via `nix flake update` (all from nixpkgs)

### lze Dependency Patterns
- `on_require = 'module'` — load plugin when `require('module')` is called
- `dep_of = 'plugin-name'` — load before the named plugin
- `on_plugin = 'plugin-name'` — load after the named plugin
- **NO `dep` field** — this does not exist in lze

### Structure
```
config/nvim/
├── init.lua          # nix-info setup, load core, auto-discover plugin configs
├── .stylua.toml      # Lua formatter config
└── lua/
    ├── core/
    │   ├── init.lua      # Loads all core modules
    │   ├── options.lua   # Vim options
    │   ├── autocmds.lua  # Autocommands
    │   ├── mappings.lua  # Keymaps
    │   └── lsp.lua       # LSP configuration (workspace.library for vim types)
    └── plugins/
        ├── deps.lua      # Library plugin on_require registrations
        └── *.lua         # Per-plugin configs (each calls require('lze').load)
```

### LSP Setup (`core/lsp.lua`)
**Enabled LSPs**:
- `lua_ls` - Lua
- `ts_ls` - TypeScript/JavaScript
- `gopls` - Go
- `cairo_ls` - Cairo (Starknet)
- `nixd` - Nix (with flake-aware nixpkgs expression)
- `basedpyright` + `ruff` - Python
- `just_ls` - Justfiles
- `solidity_ls_nomicfoundation` - Solidity

**LSP Features**:
- Auto-show diagnostics on cursor hold
- Document highlighting
- Custom diagnostic signs with Nerd Font icons

### Key Plugins
| Plugin | Purpose | Key binding |
|--------|---------|-------------|
| fzf-lua | Fuzzy finder | `<leader>f*` |
| neo-tree | File explorer | `<leader>e` |
| blink.cmp | Completion | `<Tab>`, `<Enter>` |
| rustacean.nvim | Rust IDE | `<leader>c*` |
| grug-far | Find & replace | `<leader>q*` |
| harpoon | Quick file nav | (configured) |
| trouble.nvim | Diagnostics | (configured) |

### Colemak Adaptation
- hjkl keys are unbound (uses Karabiner extend layer)
- Navigation: n/e/i/u (Colemak arrow positions)
- `;` → `:` for command mode
- `ii` → `<Esc>` in insert mode

---

## 6. WezTerm Configuration

**Location**: `config/wezterm/init.lua`

### Features
- **Frontend**: WebGPU (120 FPS)
- **Leader key**: `Ctrl-b` (tmux-like)
- **Tab bar**: Bottom, hidden if single tab
- **Window**: No decorations except resize, auto-maximize on startup

### Key Bindings (Leader = Ctrl-b)
| Key | Action |
|-----|--------|
| `v` | Split vertical |
| `h` | Split horizontal |
| `x` | Close pane |
| `n/i/u/e` | Navigate panes (Colemak) |
| `f` | Toggle zoom |
| `1-9` | Switch tabs |
| `,` | Rename tab |
| `r` | Enter resize mode |
| `z` | Fuzzy workspace switcher |

### Special: Toggle Terminal (`Ctrl-t`)
Custom callback that:
1. Creates bottom pane if none exists
2. Toggles zoom if pane exists
3. Switches focus appropriately

---

## 7. Shell Environment (Zsh)

**Location**: `home/shell.nix`

### Enabled Programs
| Tool | Purpose |
|------|---------|
| zsh | Shell with autosuggestions, syntax highlighting |
| starship | Prompt (git status, cmd duration) |
| fzf | Fuzzy finder + fzf-git.sh integration |
| atuin | Shell history |
| zoxide | Smart cd |
| direnv | Per-directory environments |
| carapace | Completion engine |
| eza | Enhanced ls |
| bat | Enhanced cat |
| fd | Enhanced find |
| ripgrep | Enhanced grep |
| yazi | TUI file manager |

### Aliases
```nix
t = "yy";       # Yazi
lg/g = "lazygit";
a = "claude";
e = "nvim";
x = "exit";
ls = "eza -a";
cat = "bat";
```

### Environment Setup (`initContent`)
- Increases file descriptor limits
- Sources fzf-git.sh for git-aware fzf
- Exports API keys from SOPS secrets
- Adds Homebrew and Cargo to PATH

---

## 8. Yazi File Manager

**Location**: `config/yazi/`

### Plugins
- **yamb.yazi**: Bookmark manager (from flake input)

### Key Bindings
| Key | Action |
|-----|--------|
| `<Enter>` | Open in nvim |
| `br` | Go to ~/Repos |
| `bm` | Go to ~/.config/nix-darwin |
| `ua` | Add bookmark |
| `ug` | Jump by key |
| `uG` | Jump by fzf |

---

## 9. System Services

### skhd (Hotkey Daemon)
**Location**: `system/default.nix` → `services.skhd`

Uses `hyper` key (caps lock remapped via Karabiner):

| Hotkey | Application |
|--------|-------------|
| `hyper + r` | LibreWolf |
| `hyper + t` | WezTerm |
| `hyper + c` | Claude |
| `hyper + s` | Slack |
| `hyper + b` | Brave |
| `hyper + d` | Discord |
| `hyper + w` | WhatsApp |
| `hyper + m` | Ableton Live |
| `hyper + l` | Signal |
| `hyper + p` | Spotify |

### LibreWolf Auto-Updater
**Location**: `scripts/install-librewolf.sh`

**Implementation**:
- Fetches latest version from GitLab API
- Compares with installed version
- Downloads ARM64 DMG, mounts, copies to /Applications
- Removes quarantine attribute
- Runs on system activation

---

## 10. Custom Packages (Overlay)

**Location**: `overlays/default.nix`, `pkgs/`

### Architecture
- Packages defined in `pkgs/*.nix` using callPackage pattern
- Exposed via overlay in `overlays/default.nix`
- Each package has `passthru.tests` for CI verification
- Tests run automatically via `nix flake check`

### Packages

| Package | Purpose |
|---------|---------|
| `unclog` | Rust changelog tool (with 1.80+ compat patch) |
| `nomicfoundation_solidity_language_server` | Hardhat Solidity LSP |
| `claude_formatter` | Auto-formatter for Claude Code hooks |
| `tidal_script` | vim-tidal wrapper for TidalCycles |

### Test Pattern
```nix
passthru.tests.pkgname = mkTest "pkgname" ''
  ${final.pkgname}/bin/pkgname --help > /dev/null
'';
```

---

## 11. Git Configuration

**Location**: `home/common/git.nix`

### Features
- SSH signing via Secretive (Secure Enclave backed)
- Delta as pager (syntax highlighting)
- Histogram diff algorithm
- Auto-setup remote on push
- Autosquash/autostash for rebase
- `url."git@github.com:".insteadOf` rewrites HTTPS to SSH (enables forwarded Secretive agent on NixOS VM)

### Global Ignores
- `.serena/`
- `.claude/`
- `CLAUDE.md`

---

## 12. Homebrew Integration

**Location**: `system/homebrew.nix`

### Behavior
- Auto-update on activation
- Auto-upgrade packages
- `zap` cleanup (removes unmanaged casks)

### Notable Casks
- supercollider, blackhole-* (audio)
- orbstack (Docker alternative)
- karabiner-elements (keyboard)
- proton-mail, protonvpn, proton-drive (privacy)
- secretive (SSH key management)

---

## 13. CI/CD & Automation

**Location**: `.github/workflows/`

### Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `check.yml` | PR, push to main | Flake check, build, lint (Lua, Nix, TOML, shell, actions), typos, gitleaks |
| `vulns.yml` | PR, push to main, daily 8am UTC | Vulnerability scanning with vulnix |
| `update-flake.yml` | Daily at 12pm UTC | Auto-update flake.lock and create PR |

### Local Commands

| Command | Purpose |
|---------|---------|
| `just check` | Run all lint checks |
| `just cache` | Build and push to Cachix |

### Git Hooks (`.githooks/`)
- **pre-commit**: `just fmt`
- **pre-push**: `just check && just cache`

Enable with `just setup-hooks`

---

## 14. Notification System

**Location**: `config/claude/hooks/notify.sh`

**Implementation**:
- Triggers on Claude Code `Notification` hook event (idle_prompt, permission_prompt)
- macOS: `osascript` desktop notification with Glass sound
- Phone: ntfy.sh push notification (topic from SOPS `ntfy-topic` secret)
- jq parsing uses `<<<` heredoc with `2>/dev/null || fallback` for robustness
- curl runs backgrounded (`&`) to avoid blocking Claude

---

## 15. NixOS VM (UTM)

**Key details**:
- Shell-only VM (no GUI packages)
- SSH agent forwarding from macOS Secretive (`forwardAgent = true` in `utm-nixos` match block)
- Hardware config committed to repo (`system/nixos/hardware-configuration.nix`) — forkers regenerate
- `just switch` uses `nixos-rebuild switch` pattern via `sudo ./result/bin/switch-to-configuration switch`
- Git URL rewrite ensures SSH auth works with forwarded agent
