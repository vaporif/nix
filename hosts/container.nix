{
  inputs,
  lib,
  config,
  ...
}: {
  imports = [./common.nix];

  # custom.system is supplied per-target by the flake (aarch64-linux / x86_64-linux).
  custom = {
    hostname = "container";
    user = lib.mkForce "root"; # common.nix sets it plainly to "vaporif"
    homeDir = "/root";
    configPath = "/root/.config/nix";
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
  # standalone HM build has no system module, so install it here. Runs as root
  # in the container, which owns /etc. Yields the non-secret servers only
  # (github, nixos, context7) — tavily/gitlab/ferrex stay gated off.
  home.activation.claudeManagedMcp = lib.hm.dag.entryAfter ["writeBoundary"] ''
    $DRY_RUN_CMD mkdir -p /etc/claude-code
    $DRY_RUN_CMD ln -sf ${config.custom.codeMcpServersConfig} /etc/claude-code/managed-mcp.json
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
