{
  pkgs,
  config,
  ...
}: let
  cfg = config.custom;
  hmCfg = config.home-manager.users.${cfg.user}.custom;
in {
  imports = [
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
    home = cfg.homeDir;
    isNormalUser = true;
    extraGroups = ["wheel"];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      cfg.git.signingKey
    ];
  };

  nixpkgs.hostPlatform = cfg.system;

  environment.etc."claude-code/managed-mcp.json".source = hmCfg.codeMcpServersConfig;

  system.stateVersion = "25.11";
}
