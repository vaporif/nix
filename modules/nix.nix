{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.custom;
in {
  nix.extraOptions = lib.mkIf (cfg.secrets.nix-access-tokens != null) ''
    !include ${cfg.secrets.nix-access-tokens}
  '';

  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    auto-optimise-store = true;
    max-jobs = "auto";
    cores = 0;
    # Determinate Nix 3.21.1's parallel evaluator crashes with
    # "polling file descriptor: Invalid argument" on the full-system eval.
    # Pin to a single eval core until the upstream bug is fixed.
    # eval-cores is a Determinate Nix extension — not recognized on standard NixOS Nix.
    eval-cores = lib.mkIf pkgs.stdenv.isDarwin 1;
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
