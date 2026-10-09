{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.custom;
  secretsPath = ../secrets/secrets.yaml;
  ownership = {
    owner = cfg.user;
    group =
      if pkgs.stdenv.hostPlatform.isDarwin
      then "staff"
      else "users";
    mode = "0400";
  };
in {
  sops = lib.mkIf cfg.secrets.enable {
    defaultSopsFile = secretsPath;
    age = {
      keyFile = "${cfg.homeDir}/.config/sops/age/key.txt";
      sshKeyPaths = [];
    };
    gnupg.sshKeyPaths = [];
    secrets = lib.genAttrs (import ./secrets.nix lib).available (_: ownership);
  };
}
