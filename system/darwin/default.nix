{
  pkgs,
  user,
  userConfig,
  ...
}: {
  imports = [
    ../../modules/nix.nix
    ../../modules/theme.nix
    ./preferences.nix
    ./services.nix
    ./activation.nix
    ./security.nix
    ./homebrew.nix
  ];

  time.timeZone = userConfig.timezone;

  environment.systemPackages = with pkgs; [
    age
    libressl
  ];

  # Address the Determinate error
  nix.enable = false;

  system = {
    configurationRevision = null;
    stateVersion = 6;
    primaryUser = user;
  };

  nixpkgs.hostPlatform = userConfig.system;
}
