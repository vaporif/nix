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

  nix.settings =
    {
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
    }
    # The Linux hosts are VMs with far less RAM than cores. Leaving cores at 0
    # lets each of the 4 jobs claim every core, so a single flake build can put
    # ~48 compilers on 14 GiB and drive the machine into memory pressure.
    // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
      max-jobs = 4;
      cores = 2;
    }
    # Determinate Nix 3.21.1's parallel evaluator crashes with
    # "polling file descriptor: Invalid argument" on the full-system eval.
    # eval-cores is a Determinate Nix extension not recognized by standard NixOS Nix.
    // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {eval-cores = 1;};
}
