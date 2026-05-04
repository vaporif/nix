{
  config,
  lib,
  ...
}: let
  cfg = config.custom;
in {
  environment.etc."nix/nix.custom.conf" = lib.mkIf (cfg.secrets.nix-access-tokens != null) {
    text = lib.mkAfter ''
      !include ${cfg.secrets.nix-access-tokens}
    '';
  };
  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    auto-optimise-store = true;
    max-jobs = "auto";
    cores = 0;
    substituters =
      [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
      ]
      ++ lib.optionals (cfg.cachix.name != "") ["https://${cfg.cachix.name}.cachix.org"];
    trusted-public-keys =
      [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ]
      ++ lib.optionals (cfg.cachix.publicKey != "") [cfg.cachix.publicKey];
  };
}
