# Implementation Details

This document describes what's implemented in this nix-darwin configuration and how each component is structured.

---

## 1. Configuration Architecture

### Module Hierarchy
```
hosts/common.nix (shared user config: user, git, cachix, timezone)
hosts/macbook.nix (macOS host: hostname, system, configPath, sshAgent)
hosts/nixos.nix (Linux host: hostname, system, configPath, sshAgent)
flake.nix (entry point, mkHostContext builds per-host derived values)
├── Inputs: nixpkgs, nix-darwin, home-manager, sops-nix, stylix, mcp-servers-nix
├── Overlays: localPackages (custom packages), allowUnfreePredicate
│
├── system/
│   ├── darwin/ (macOS system configuration)
│   │   ├── default.nix - Nix settings, system defaults, skhd hotkeys
│   │   ├── theme.nix - Stylix theming
│   │   ├── security.nix - SOPS secrets, firewall, TouchID
│   │   └── homebrew.nix - Homebrew casks
│   └── nixos/ (NixOS system configuration)
│       └── default.nix - openssh, user account, nix settings
│
├── home/ (Home Manager user configuration)
│   ├── default.nix - Programs: git, neovim, wezterm, gh, lazygit
│   ├── packages.nix - User packages + custom derivations
│   └── shell.nix - Zsh, shell tools, aliases
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
- **Separation of concerns**: System-level config in `system/`, user-level in `home/`, dotfiles in `config/`
- **Modular imports**: Each concern has its own file
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

**Location**: `mcp.nix` (config), `flake.nix` (mcpServersConfig built once and passed via specialArgs)

**Implementation**:
- Uses `mcp-servers-nix` flake for declarative MCP config
- Config generated once in `flake.nix` via `mcp-servers-nix.lib.mkConfig`
- `mcpServersConfig` passed to both system and home-manager via specialArgs (deduplicated)
- Output written to multiple locations:
  - `/Library/Application Support/ClaudeCode/managed-mcp.json` (via activation script)
  - `~/Library/Application Support/Claude/claude_desktop_config.json`
  - `~/.config/mcphub/servers.json`

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

**Location**: `config/nvim/` directory, managed via `xdg.configFile.nvim`

### Structure
```
config/nvim/
├── init.lua          # Bootstrap lazy.nvim, load core & plugins
├── lazy-lock.json    # Plugin version lockfile (committed)
├── .stylua.toml      # Lua formatter config
└── lua/
    ├── core/
    │   ├── init.lua      # Loads all core modules
    │   ├── options.lua   # Vim options
    │   ├── autocmds.lua  # Autocommands
    │   ├── mappings.lua  # Keymaps
    │   └── lsp.lua       # LSP configuration
    └── plugins/          # 34 plugin configs (lazy-loaded)
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

**Location**: `home/default.nix` → `programs.git`

### Features
- SSH signing via Secretive (Secure Enclave backed)
- Delta as pager (syntax highlighting)
- Histogram diff algorithm
- Auto-setup remote on push
- Autosquash/autostash for rebase

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
