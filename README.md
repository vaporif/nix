# Nix-darwin + home-manager

Personal Nix config for macOS and NixOS. Uses [nix-darwin](https://github.com/nix-darwin/nix-darwin), [NixOS](https://nixos.org), and [home-manager](https://github.com/nix-community/home-manager).

- **macOS** -- nix-darwin + Home Manager
- **NixOS** -- NixOS + Home Manager (shell-only VM)

## Forking this config

### Prerequisites

1. Install [Nix](https://determinate.systems/nix-installer/)
2. **macOS only**: Install [Homebrew](https://brew.sh/)
3. **NixOS**: A working NixOS installation

### Quick setup

```shell
git clone https://github.com/YOUR-USERNAME/nix.git ~/.config/nix-darwin
cd ~/.config/nix-darwin

# Detects platform, configures host files, generates age key
./scripts/setup.sh

# Create and encrypt your secrets
sops secrets/secrets.yaml

# First-time build (just/nom/nvd aren't available yet)
# Replace `<hostname>` with the value of `custom.hostname` from your host file
# (e.g. `hosts/macbook.nix` or `hosts/nixos.nix`).

# macOS:
nix build ".#darwinConfigurations.<hostname>.system"
sudo ./result/activate

# NixOS:
nix build ".#nixosConfigurations.<hostname>.config.system.build.toplevel"
sudo ./result/bin/switch-to-configuration switch

# After first build, use: just switch

direnv allow ~
```

> **Forking:** `just switch` and `just cache` hardcode the host attribute
> names (`burnedapple` / `nixos`). If you change `hostname` in your host file,
> either match one of those names or edit the recipes in `justfile`.

### Manual setup

1. **Edit host config** in `hosts/`:
   - Copy an existing host file (e.g., `hosts/macbook.nix`) and set:
   - `hostname`, `system`, `configPath`, `sshAgent` (`"secretive"` for macOS, `""` otherwise)
   - Edit `hosts/common.nix` for shared values (`user`, `git.*`, `cachix.*`, `timezone`)

2. **Generate age key**:
   ```shell
   mkdir -p ~/.config/sops/age
   age-keygen -o ~/.config/sops/age/key.txt
   ```

3. **Update `.sops.yaml`** with your public key

4. **Create secrets**:
   ```shell
   cp secrets/secrets.yaml.template secrets/secrets.yaml
   sops -e -i secrets/secrets.yaml
   ```

5. **Build** (same commands as quick setup above, then `just switch` going forward)

6. **Vimium-ff**: Paste contents of `config/librewolf/vimium.cfg` into Vimium options → Custom key mappings (not yet supported via policies, see [philc/vimium#4738](https://github.com/philc/vimium/issues/4738))

## SOPS secrets

Secrets are encrypted with [SOPS](https://github.com/getsops/sops) + age. `sops secrets/secrets.yaml` opens your editor with decrypted content, re-encrypts on save.

To add a secret: put it in `secrets/secrets.yaml`, define it in nix (`sops.secrets.my-secret = { };`), read it at `/run/secrets/my-secret`.

## AI sandboxing

AI coding agents get filesystem and network access by default. That means they can read your dotfiles, tokens, SSH keys, whatever. This config wraps Claude Code in OS-level sandboxes so it can only touch what you allow.

### Why SOPS matters here

Without SOPS, API tokens live in plaintext dotfiles, readable by any process. With SOPS, secrets decrypt at runtime to `/run/secrets/`, get loaded as env vars *before* the sandbox starts, and the sandbox itself never has filesystem access to the secret files.

### macOS: sandnix

[sandnix](https://github.com/srid/sandnix) wraps Claude Code in Apple's `sandbox-exec`. Filesystem is locked to `$PWD`, `~/.claude`, and `~/Repos`. Mach services are scoped down to DNS, keychain, and notifications. Network is open (Claude needs API access).

See `home/darwin/sandboxed.nix`.

### Linux: bubblewrap

[bubblewrap](https://github.com/containers/bubblewrap) on NixOS. Empty `$HOME` with selective bind mounts, read-only Nix store, minimal `/etc`. SSH agent forwarding works, private keys stay outside the sandbox.

See `home/linux/sandboxed.nix`.

### Aliases

The AI aliases (`a`, `ap`, `ar`, `ai`) all go through the sandboxed wrapper. Unwrapped binary isn't on `$PATH`.

## Development

Run `just` to list everything. The ones you'll use most:

| Command | What it does |
|---------|-------------|
| `just switch` | Apply config (auto-detects platform) |
| `just check` | Lint everything |
| `just fmt` | Format all files |
| `just check-vulns` | Scan for vulnerabilities |
| `just gc 30d` | Clean up old generations |
| `just lazy-update` | Update neovim plugins |
| `just cache` | Build and push to Cachix |

### Git hooks

```shell
just setup-hooks    # auto-format on commit, lint + cache on push
git commit --no-verify  # skip when needed
```

### Cachix

```shell
cachix authtoken <your-token>
just cache
```

## Shell aliases

| Alias | Command | What it does |
|-------|---------|-------------|
| `a` | `claude` | Claude Code (sandboxed) |
| `ap` | `claude --print` | Claude print mode |
| `ai` | `claude --dangerously-skip-permissions` | Claude autonomous mode |
| `ar` | `claude --resume` | Resume last session |
| `e` | `nvim` | Neovim |
| `g` | `lazygit` | Git TUI |
| `t` | `yy` | Yazi file manager |
| `ls` | `eza -a` | ls with hidden files |
| `cat` | `bat` | Cat with syntax highlighting |
| `x` | `exit` | Exit shell |
| `mcp-scan` | `uv tool run mcp-scan@latest` | MCP server scanner |
| `init-solana` | `nix flake init -t ...#solana` | Solana project template |
| `init-rust` | `nix flake init -t ...#rust` | Rust project template |

## Keybindings

See [docs/keymaps.md](docs/keymaps.md), auto-generated with `just keymaps` (Neovim, skhd, Karabiner, WezTerm, Yazi).

## Learning

- https://nix.dev/recommended-reading
