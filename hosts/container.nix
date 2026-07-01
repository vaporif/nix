{
  inputs,
  lib,
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
      bashGuard.enable = false;
    };
    codex.enable = false;
    qdrant.enable = false;
    tmux.autoAttach = false;
    gitlab.enable = false;
    yaziBookmarks = [];
  };

  home.stateVersion = "24.05";

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
