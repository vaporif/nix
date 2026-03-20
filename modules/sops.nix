{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.custom;
in {
  sops = {
    defaultSopsFile = ../secrets/secrets.yaml;
    age = {
      keyFile = "${cfg.homeDir}/.config/sops/age/key.txt";
      sshKeyPaths = [];
    };
    gnupg.sshKeyPaths = [];
    secrets =
      lib.genAttrs
      ["openrouter-key" "tavily-key" "youtube-key" "hf-token-scan-injection" "ntfy-topic" "nix-access-tokens"]
      (_: {
        owner = cfg.user;
        group =
          if pkgs.stdenv.isDarwin
          then "staff"
          else "users";
        mode = "0400";
      });
  };
}
