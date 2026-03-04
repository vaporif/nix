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
    ./hardware-configuration.nix
    ./security.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = cfg.hostname;
  networking.networkmanager.enable = true;

  time.timeZone = cfg.timezone;

  programs.zsh.enable = true;

  environment.systemPackages = with pkgs; [
    age
  ];

  users.users.${cfg.user} = {
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      cfg.git.signingKey
    ];
  };

  nixpkgs.hostPlatform = cfg.system;

  system.stateVersion = "25.11";
}
