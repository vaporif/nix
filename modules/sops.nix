{
  pkgs,
  lib,
  user,
  homeDir,
  ...
}: {
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
        owner = user;
        group =
          if pkgs.stdenv.isDarwin
          then "staff"
          else "users";
        mode = "0400";
      });
  };
}
