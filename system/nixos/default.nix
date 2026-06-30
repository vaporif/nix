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

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 10d";
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = cfg.hostname;
  networking.networkmanager.enable = true;

  time.timeZone = cfg.timezone;

  services.journald.storage = "persistent";

  console.keyMap = "colemak";

  # TODO: Re-enable once Stylix migrates from the removed services.kmscon.fonts
  # and services.kmscon.extraConfig options to services.kmscon.config.
  stylix.targets.kmscon.enable = false;

  programs.zsh.enable = true;

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
  };

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  systemd.oomd = {
    enable = true;
    enableUserSlices = true;
    settings.OOM.DefaultMemoryPressureDurationSec = "20s";
  };

  environment.systemPackages = [
    pkgs.age
  ];

  users.users.${cfg.user} = {
    home = cfg.homeDir;
    isNormalUser = true;
    extraGroups = ["wheel"];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys =
      lib.optional (cfg.git.signingKey != "") cfg.git.signingKey
      ++ cfg.sshAuthorizedKeys;
  };

  environment.etc = lib.mkIf hmCfg.claude.enable {
    "claude-code/managed-mcp.json".source = hmCfg.codeMcpServersConfig;
  };

  system.stateVersion = cfg.stateVersion;
}
