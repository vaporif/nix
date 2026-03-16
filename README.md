# Nix-darwin + home-manager

Cross-platform personal configuration using [nix-darwin](https://github.com/nix-darwin/nix-darwin), [NixOS](https://nixos.org), and [home-manager](https://github.com/nix-community/home-manager).

- **macOS** — nix-darwin system config + Home Manager
- **NixOS** — NixOS system config + Home Manager (shell-only VM)

## Forking This Config

### Prerequisites

1. Install [Nix](https://determinate.systems/nix-installer/)
2. **macOS only**: Install [Homebrew](https://brew.sh/)
3. **NixOS**: A working NixOS installation

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

# First-time build (just/nom/nvd aren't available yet)
# macOS:
hostname=$(nix eval --raw -f hosts/macbook.nix hostname)
nix build ".#darwinConfigurations.${hostname}.system"
sudo ./result/activate

# NixOS:
hostname=$(nix eval --raw -f hosts/nixos.nix hostname)
nix build ".#nixosConfigurations.${hostname}.config.system.build.toplevel"
sudo ./result/bin/switch-to-configuration switch

# After first build, use: just switch

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

5. **Apply** (first time — `just` isn't installed yet):
   ```shell
   # macOS:
   hostname=$(nix eval --raw -f hosts/macbook.nix hostname)
   nix build ".#darwinConfigurations.${hostname}.system"
   sudo ./result/activate

   # NixOS:
   hostname=$(nix eval --raw -f hosts/nixos.nix hostname)
   nix build ".#nixosConfigurations.${hostname}.config.system.build.toplevel"
   sudo ./result/bin/switch-to-configuration switch
   ```
   After first build, use `just switch` for all subsequent changes.

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

See [docs/keymaps.md](docs/keymaps.md) — auto-generated with `just keymaps` (Neovim, skhd, Karabiner, WezTerm, Yazi).


## Learning

- https://nix.dev/recommended-reading
