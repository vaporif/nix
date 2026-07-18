{
  inputs,
  lib,
  config,
  ...
}: {
  imports = [./common.nix];

  # custom.system is supplied per-target by the flake (aarch64-linux / x86_64-linux).
  # Identity (user/homeDir/configPath) is set by the thin per-target wrappers:
  # container.nix (rootless docker → root), devcontainer.nix (VS Code → vscode).
  custom = {
    hostname = "container";
    secrets.enable = false;
    claude = {
      enable = true;
      sandbox = false; # bwrap can't nest in a rootless container
    };
    codex.enable = false;
    qdrant.enable = false;
    tmux.autoAttach = false;
    gitlab.enable = false;
    yaziBookmarks = [];
    # docker-dev.sh bind-mounts the host ~/.ssh read-only; dropping the signing
    # key stops HM writing .ssh/allowed_signers + signing_key.pub into it (the
    # host's ssh/git identity is used instead).
    git.signingKey = "";
  };

  # Same reason: don't generate ~/.ssh/config over the read-only host mount.
  programs.ssh.enable = lib.mkForce false;

  home.stateVersion = "24.05";

  # On real hosts the NixOS/darwin system module writes managed-mcp.json; a
  # standalone HM build has no system module, so install it here. Yields the
  # non-secret servers only (github, nixos, context7) — tavily/gitlab/ferrex
  # stay gated off. /etc is root-owned inside the container, so guard the write:
  # the rootless container activates as root and succeeds, while an unprivileged
  # devcontainer activation (vscode) skips it instead of aborting the whole run.
  home.activation.claudeManagedMcp = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ -w /etc ] || [ -w /etc/claude-code ]; then
      $DRY_RUN_CMD mkdir -p /etc/claude-code
      $DRY_RUN_CMD ln -sf ${config.custom.codeMcpServersConfig} /etc/claude-code/managed-mcp.json
    else
      echo "claudeManagedMcp: /etc not writable, skipping managed-mcp.json" >&2
    fi
  '';

  # earthtone-light, same as modules/theme.nix but HM-compatible (no font packages).
  stylix = {
    enable = true;
    polarity = "light";
    base16Scheme = let
      t = fromTOML (
        builtins.readFile "${inputs.earthtone-nvim}/extras/base16-earthtone-light.toml"
      );
    in
      t.palette // {inherit (t.scheme) name author;};
  };
}
