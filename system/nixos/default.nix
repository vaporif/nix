{
  pkgs,
  user,
  userConfig,
  ...
}: {
  imports = [
    ../../modules/nix.nix
    ../../modules/theme.nix
    ./hardware-configuration.nix
    ./security.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = userConfig.hostname;
  networking.networkmanager.enable = true;

  time.timeZone = userConfig.timezone;

  programs.zsh.enable = true;

  environment.systemPackages = with pkgs; [
    age
  ];

  users.users.${user} = {
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      userConfig.git.signingKey
    ];
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  nixpkgs.hostPlatform = userConfig.system;

  system.stateVersion = "25.11";
}
