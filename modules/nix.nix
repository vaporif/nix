# Shared nix.settings across all hosts
{userConfig, ...}: {
  nix.extraOptions = ''
    !include /run/secrets/nix-access-tokens
  '';
  nix.settings = {
    experimental-features = "nix-command flakes";
    auto-optimise-store = true;
    max-jobs = "auto";
    cores = 0; # use all cores
    substituters =
      [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
      ]
      ++ (
        if userConfig.cachix.name != ""
        then ["https://${userConfig.cachix.name}.cachix.org"]
        else []
      );
    trusted-public-keys =
      [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ]
      ++ (
        if userConfig.cachix.publicKey != ""
        then [userConfig.cachix.publicKey]
        else []
      );
  };
}
