{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.custom;
  homeDir =
    if pkgs.stdenv.isDarwin
    then "/Users/${cfg.user}"
    else "/home/${cfg.user}";
in {
  sops = {
    defaultSopsFile = ../secrets/secrets.yaml;
    age = {
      keyFile = "${homeDir}/.config/sops/age/key.txt";
      sshKeyPaths = [];
    };
    gnupg.sshKeyPaths = [];
    secrets =
      lib.genAttrs
      ["openrouter-key" "tavily-key" "youtube-key" "deepl-key" "hf-token-scan-injection" "ntfy-topic" "nix-access-tokens"]
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
