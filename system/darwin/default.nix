{
  pkgs,
  config,
  ...
}: let
  cfg = config.custom;
in {
  imports = [
    ../../modules/options.nix
    ../../modules/nix.nix
    ../../modules/theme.nix
    ./preferences.nix
    ./services.nix
    ./activation.nix
    ./security.nix
    ./homebrew.nix
  ];

  time.timeZone = cfg.timezone;

  environment.systemPackages = with pkgs; [
    age
    libressl
  ];

  nix.enable = false;

  system = {
    configurationRevision = null;
    stateVersion = 6;
    primaryUser = cfg.user;
  };

  nixpkgs.hostPlatform = cfg.system;
}
