{
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.custom;
  hmCfg = config.home-manager.users.${cfg.user}.custom;
in {
  imports = [
    ../../modules/nix.nix
    ../../modules/theme.nix
    ./security.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = cfg.hostname;
  networking.networkmanager.enable = true;

  time.timeZone = cfg.timezone;

  console.keyMap = "colemak";

  # TODO: Re-enable once Stylix migrates from the removed services.kmscon.fonts
  # and services.kmscon.extraConfig options to services.kmscon.config.
  stylix.targets.kmscon.enable = false;

  programs.zsh.enable = true;

  environment.systemPackages = [
    pkgs.age
  ];

  users.users.${cfg.user} = {
    home = cfg.homeDir;
    isNormalUser = true;
    extraGroups = ["wheel"];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [cfg.git.signingKey] ++ cfg.sshAuthorizedKeys;
  };

  environment.etc = lib.mkIf hmCfg.claude.enable {
    "claude-code/managed-mcp.json".source = hmCfg.codeMcpServersConfig;
  };

  system.stateVersion = cfg.stateVersion;
}
