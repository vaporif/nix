# Nix-darwin + home-manager

Cross-platform personal configuration using [nix-darwin](https://github.com/nix-darwin/nix-darwin), [NixOS](https://nixos.org), and [home-manager](https://github.com/nix-community/home-manager).

- **macOS** — nix-darwin system config + Home Manager
- **NixOS** — NixOS system config + Home Manager (shell-only VM)

## Forking This Config

### Prerequisites

1. Install [Nix](https://determinate.systems/nix-installer/)
2. **macOS only**: Install [Homebrew](https://brew.sh/) and [nix-darwin](https://github.com/nix-darwin/nix-darwin)

### Quick Setup

```shell
# Clone your fork
git clone https://github.com/YOUR-USERNAME/nix.git ~/.config/nix-darwin
cd ~/.config/nix-darwin

# Run setup script (works on macOS and Linux)
# Detects platform, configures host files, generates age key
./scripts/setup.sh

# Create and encrypt your secrets
sops secrets/secrets.yaml

# Apply configuration (auto-detects platform)
just switch

# Allow direnv for default devshell
direnv allow ~
```

### Manual Setup

If you prefer manual configuration:

1. **Edit host config** in `hosts/`:
   - Copy an existing host file (e.g., `hosts/macbook.nix`) and override:
   - `hostname` - your machine name
   - `system` - `"aarch64-darwin"`, `"x86_64-darwin"`, `"aarch64-linux"`, or `"x86_64-linux"`
   - `configPath` - path to this repo
   - `sshAgent` - `"secretive"` for macOS Secretive.app, `""` otherwise
   - Edit `hosts/common.nix` for shared values (`user`, `git.*`, `cachix.*`, `timezone`)

2. **Generate age key** for secrets:
   ```shell
   mkdir -p ~/.config/sops/age
   age-keygen -o ~/.config/sops/age/key.txt
   ```

3. **Update `.sops.yaml`** with your public key

4. **Create secrets** from template:
   ```shell
   cp secrets/secrets.yaml.template secrets/secrets.yaml
   sops -e -i secrets/secrets.yaml
   ```

5. **Apply**:
   ```shell
   just switch
   ```

## Working with SOPS Secrets

Secrets are encrypted using [SOPS](https://github.com/getsops/sops) with age encryption.

### Editing Secrets

```shell
sops secrets/secrets.yaml
```

Opens your `$EDITOR` with decrypted content. Changes are re-encrypted on save.

### Adding New Secrets

1. Edit `secrets/secrets.yaml` and add your secret
2. Define in nix (e.g., `system/security.nix`):
   ```nix
   sops.secrets.my-new-secret = { };
   ```
3. Access at runtime: `/run/secrets/my-new-secret`

## Development

Run `just` to see available commands:

| Command | Description |
|---------|-------------|
| `just switch` | Apply configuration (auto-detects platform) |
| `just check` | Run all checks (lint + policy) |
| `just check-policy` | Run policy checks (freshness, pinning) |
| `just fmt` | Format all files |
| `just cache` | Build and push to Cachix |
| `just setup-hooks` | Enable git hooks |

### Git Hooks

Enable git hooks (auto-format on commit, lint + cache on push):
```shell
just setup-hooks
```

Skip hooks when needed:
```shell
git commit --no-verify
git push --no-verify
```

### Policy Enforcement

Security and compliance checks run in CI and locally:
- **Vulnerability scanning** - `vulnix` with whitelist for false positives
- **Input freshness** - Warns if flake inputs are >30 days old
- **Pinned inputs** - Fails if any inputs are unpinned (indirect)
- **Secret scanning** - `gitleaks` prevents committing secrets
- **License compliance** - Unfree packages must be explicitly allowlisted

Run locally: `just check-vulns` or `just check-policy`

### Cachix

Binary cache for faster builds:
```shell
cachix authtoken <your-token>
just cache
```

## Shell Aliases

| Alias | Command | Description |
|-------|---------|-------------|
| `a` | `claude` | Claude Code CLI |
| `ap` | `claude --print` | Claude Code print mode |
| `ai` | `claude --dangerously-skip-permissions` | Claude Code autonomous |
| `ar` | `claude --resume` | Claude Code resume session |
| `e` | `nvim` | Neovim |
| `g` | `lazygit` | Git TUI |
| `t` | `yy` | Yazi file manager |
| `ls` | `eza -a` | Modern ls with hidden files |
| `cat` | `bat` | Cat with syntax highlighting |
| `x` | `exit` | Exit shell |
| `mcp-scan` | `uv tool run mcp-scan@latest` | MCP server scanner |
| `init-solana` | `nix flake init -t ...#solana` | Solana project template |
| `init-rust` | `nix flake init -t ...#rust` | Rust project template |

## Keybindings

### Application Shortcuts (skhd — macOS)

All use `hyper` key (Caps Lock remapped via Karabiner-Elements):

| Key | App | Key | App |
|-----|-----|-----|-----|
| `hyper + r` | Librewolf | `hyper + w` | WhatsApp |
| `hyper + t` | WezTerm | `hyper + m` | Ableton Live |
| `hyper + c` | Claude | `hyper + l` | Signal |
| `hyper + s` | Slack | `hyper + p` | Spotify |
| `hyper + b` | Brave | | |
| `hyper + d` | Discord | | |

### Karabiner-Elements

- **Caps Lock** — hold for extend layer, tap for hyper key combos
- **Extend layer** — `Caps + i/k/j/l` for arrow keys (Up/Down/Left/Right)
- **Right Option** — Escape

### WezTerm (Leader: `Ctrl+b`)

| Key | Action | Key | Action |
|-----|--------|-----|--------|
| `Leader + v` | Split vertical | `Leader + h` | Split horizontal |
| `Leader + x` | Close pane | `Leader + f` | Fullscreen pane |
| `Leader + n/i/u/e` | Navigate L/R/U/D | `Leader + Tab` | Cycle panes |
| `Leader + r` | Resize mode | `Leader + m` | Move tab mode |
| `Leader + o` | Launcher | `Leader + z` | Workspace switcher |
| `Leader + ,` | Rename tab | `Leader + /` | Search |
| `Leader + c` | Copy/scroll mode | | |
| `Ctrl + t` | Toggle bottom split | `Ctrl + /` | Toggle right split |

### Neovim (Leader: `Space`)

**Navigation:**

| Key | Action | Key | Action |
|-----|--------|-----|--------|
| `<leader>ff` | Find files | `<leader>fg` | Live grep |
| `<leader>fb` | Buffers | `<leader>fh` | Help tags |
| `<leader>fk` | Keymaps | `<leader>fd` | Diagnostics |
| `<leader>fs` | Document symbols | `<leader>fw` | Workspace symbols |
| `<leader>fr` | Resume search | `<leader>fn` | Neovim config files |
| `<leader>ft` | Git worktrees | `<leader>.` | Buffer fuzzy search |
| `gd` | Goto definition | `gR` | Goto references |
| `gI` | Goto implementation | `'` | Marks |
| `<S-h>` / `<S-l>` | Prev/next buffer | `<leader>e` | Toggle file tree |
| `<leader>a` | Harpoon add | `<leader>p` | Harpoon menu |
| `<leader>1-9` | Jump to harpoon file | | |

**Editing & Code:**

| Key | Action | Key | Action |
|-----|--------|-----|--------|
| `<leader>w` | Write file | `<leader>/` | Toggle comment |
| `<leader>qg` | Global search/replace | `<leader>qw` | Buffer search/replace |
| `<leader>sv` | Split vertical | `<leader>sh` | Split horizontal |
| `<leader>bl` | LSP definitions/refs | `<leader>cd` | Diff tool |
| `[d` / `]d` | Prev/next diagnostic | `[e` / `]e` | Prev/next error |
| `ii` | Escape (insert mode) | `;` | Command mode |

**Git (hunks):**

| Key | Action | Key | Action |
|-----|--------|-----|--------|
| `]g` / `[g` | Next/prev hunk | `<leader>hp` | Preview hunk |
| `<leader>hs` | Stage hunk | `<leader>hr` | Reset hunk |
| `<leader>hS` | Stage buffer | `<leader>hR` | Reset buffer |
| `<leader>hb` | Blame line | `<leader>hd` | Diff vs index |
| `<leader>hh` | File history | `<leader>hB` | Toggle blame |

### Yazi

| Key | Action | Key | Action |
|-----|--------|-----|--------|
| `br` | Go to ~/Repos | `bm` | Go to nix config |
| `ua` | Add bookmark | `ug` | Jump bookmark |
| `ud` | Delete bookmark | `ur` | Rename bookmark |
| `Enter` | Open in nvim | | |

## Programs & Packages

### CLI Tools (shared)

| Category | Packages |
|----------|----------|
| **Shell** | zsh, starship, atuin, fzf, zoxide, carapace, direnv |
| **Files** | eza, bat, fd, ripgrep, yazi, ouch, dua |
| **Git** | lazygit, gh (+ gh-dash), delta, difftastic |
| **Dev** | just, tokei, hyperfine, btop, procs, lazydocker, tmux |
| **Nix** | alejandra, statix, deadnix, nix-tree, nix-diff, nix-search, nvd, nix-output-monitor, cachix |
| **Linting** | stylua, selene, typos, taplo, shellcheck, actionlint, vulnix |
| **Rust** | bacon, cargo-info, rusty-man |
| **AI** | claude-code, qdrant, qdrant-web-ui |
| **Secrets** | sops, age (macOS system) |
| **Other** | yt-dlp, presenterm, tdf, wget, rsync |

### macOS Homebrew Casks

Brave, Claude, Discord, Element, GIMP, Karabiner-Elements, KeyCastr, MonitorControl,
mpv, OrbStack, Proton Drive, ProtonVPN, qBittorrent, Secretive, Signal, SuperCollider,
Syncthing, Tor Browser, UTM, WezTerm (nightly), Zoom,
BlackHole (2ch + 16ch), Cardinal

### NixOS-Specific

Shell-only VM — no GUI packages (wezterm, librewolf available on macOS only)

### Neovim Plugins

| Category | Plugins |
|----------|---------|
| **Completion** | blink.cmp, blink.pairs |
| **LSP** | nvim-lspconfig, mason.nvim, lazydev.nvim |
| **Treesitter** | nvim-treesitter |
| **Formatting** | conform.nvim |
| **Navigation** | fzf-lua, flash.nvim, harpoon, neo-tree |
| **Git** | gitsigns.nvim, diffview.nvim |
| **Editing** | yanky.nvim, substitute.nvim, grug-far.nvim, mini.nvim, marks.nvim |
| **UI** | earthtone (theme), lualine, which-key, alpha-nvim, noice.nvim, snacks.nvim |
| **Diagnostics** | trouble.nvim, todo-comments.nvim, outline.nvim |
| **Testing** | neotest (golang, python, vitest, foundry) |
| **Debug** | nvim-dap, nvim-dap-ui, nvim-dap-go |
| **Languages** | go.nvim, rustaceanvim, crates.nvim, vim-tidal-lua |
| **Utilities** | auto-session, guess-indent, early-retirement, render-markdown, nvim-ufo |

### Git Custom Commands

| Command | Description |
|---------|-------------|
| `git bclone <url>` | Bare clone with main worktree |
| `git meta push` | Sync worktree configs to `.meta/` |
| `git meta pull` | Sync `.meta/` configs to worktree |
| `git meta diff` | Show config differences |
| `git meta init` | Initialize `.meta/` from current worktree |

### Git Aliases

| Alias | Command | gh Alias | Command |
|-------|---------|----------|---------|
| `co` | `checkout` | `co` | `pr checkout` |
| `cob` | `checkout -b` | `pv` | `pr view --web` |
| `discard` | `reset HEAD --hard` | `pl` | `pr list` |
| `fp` | `fetch --all --prune` | `ps` | `pr status` |
| `bclone` | `!git-bare-clone` | `pm` | `pr merge` |
| | | `d` | `dash` |

### MCP Servers

| Server | Description |
|--------|-------------|
| **serena** | Semantic code editing (nixd, lua-ls, rust-analyzer, gopls) |
| **filesystem** | File access (Documents, config, cargo, go, nix store) |
| **git** | Git operations |
| **github** | GitHub API (uses `gh auth token`) |
| **context7** | Library documentation lookup |
| **memory** | Knowledge graph storage |
| **qdrant** | Vector DB for Claude memory |
| **nixos** | NixOS/nix-darwin option search |
| **tavily** | Web search |
| **deepl** | Translation |
| **sequential-thinking** | Reasoning chains |
| **time** | Time/timezone utilities |

### Claude Code Commands

| Command | Description |
|---------|-------------|
| `/cleanup` | Code review and cleanup of branch changes |
| `/commit` | Generate commit message from staged changes |
| `/docs` | Update all documentation |
| `/pr` | Generate PR title and description |
| `/recall` | Search Qdrant memory |
| `/remember` | Store context in Qdrant |

**Plugins:** feature-dev, ralph-wiggum, code-review

## Structure

```
flake.nix                    # Entry point, inputs, outputs for both platforms
├── hosts/
│   ├── common.nix           # Shared user config (name, git, cachix, timezone)
│   ├── macbook.nix          # macOS host overrides
│   └── nixos.nix            # NixOS host overrides
├── modules/
│   ├── nix.nix              # Shared Nix settings
│   └── theme.nix            # Shared Stylix theme
├── mcp.nix                  # MCP server configuration (shared)
├── system/
│   ├── darwin/              # macOS-only: nix-darwin system config, skhd, SOPS, firewall
│   └── nixos/               # NixOS system config: openssh, user account
├── home/
│   ├── common/              # Shared home-manager config (shell, packages, editor, etc.)
│   ├── darwin/              # macOS-specific home config
│   └── linux/               # NixOS-specific home config (systemd services)
├── overlays/                # Custom package overlays
├── pkgs/                    # Custom package definitions
├── config/                  # Dotfiles (nvim, wezterm, yazi, karabiner, etc.)
├── secrets/
│   ├── secrets.yaml         # Encrypted secrets (not in git)
│   └── secrets.yaml.template
└── scripts/
    ├── setup.sh             # Cross-platform bootstrap script for forks
    ├── git-bare-clone.sh    # Bare clone with main worktree
    ├── git-meta.sh          # Worktree config sync (.meta/)
    ├── install-librewolf.sh
    └── check-flake-age.sh   # Flake input freshness check
vulnix-whitelist.toml        # CVE whitelist for vulnix
```

## Learning

- https://nix.dev/recommended-reading
