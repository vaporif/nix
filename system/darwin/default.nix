{
  pkgs,
  config,
  ...
}: let
  cfg = config.custom;
in {
  imports = [
    ../../modules/nix.nix
    ../../modules/theme.nix
    ./preferences.nix
    ./services.nix
    ./activation.nix
    ./security.nix
    ./homebrew.nix
  ];

  time.timeZone = cfg.timezone;

  users.users.${cfg.user}.home = cfg.homeDir;

  environment.systemPackages = [
    pkgs.age
    pkgs.libressl
  ];

  nix.enable = false;

  system = {
    configurationRevision = null;
    stateVersion = 6;
    primaryUser = cfg.user;
  };

  nixpkgs.hostPlatform = cfg.system;
}
