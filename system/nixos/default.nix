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

  programs.zsh.enable = true;

  # Stylix auto-enables its regreet target on every Linux host and still writes
  # to `programs.regreet.*`, which nixpkgs renamed to
  # `services.displayManager.regreet`. These hosts are shell-only, so drop the
  # target instead of carrying the rename warning.
  stylix.targets.regreet.enable = false;

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
  };

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  systemd = {
    # The freedesktop trash spec has no expiry of its own, so anything moved to
    # ~/.local/share/Trash stays until something ages it out. `e` only touches
    # the dirs if they already exist, so no empty trash is created.
    tmpfiles.rules = [
      "e ${cfg.homeDir}/.local/share/Trash/files - - - 30d"
      "e ${cfg.homeDir}/.local/share/Trash/info - - - 30d"
    ];

    # oomd relieves pressure by killing an entire cgroup, so monitoring user
    # slices means it kills the ssh session scope — taking tmux and every shell
    # in it down along with the build that caused the pressure. Left on the
    # system slice only; earlyoom covers user memory, ranked per-process (see
    # extraArgs below for why that ranking needs help).
    oomd = {
      enable = true;
      enableUserSlices = false;
      enableSystemSlice = true;
      settings.OOM.DefaultMemoryPressureDurationSec = "20s";
    };

    # /tmp is a RAM-backed tmpfs (boot.tmp.useTmpfs) and nix-daemon builds land
    # in TMPDIR, so a large build tree is charged against memory. Point builds
    # at the disk-backed /var/tmp.
    services.nix-daemon.environment.TMPDIR = "/var/tmp";
  };

  services.earlyoom = {
    enable = true;

    # earlyoom kills only when memory AND swap are both under threshold, so a
    # deep swap keeps it inert until the box is already thrashing. 100 makes
    # the swap term always true — memory pressure alone triggers it.
    freeMemThreshold = 10;
    freeSwapThreshold = 100;

    # earlyoom ranks victims by oom_score, not by RSS, and oom_score folds in
    # oom_score_adj — so an 11 MiB `systemd --user` (adj 100) outranks a 12 GB
    # runaway. It killed the user manager three times in three days, which
    # tears down user@.service, every tmux scope under it and the ssh login.
    # Names are matched against comm, truncated to 15 chars — hence
    # `dbus-broker-lau` and `.claude-unwrapp` rather than their full names.
    extraArgs = [
      "--avoid"
      "^(systemd|dbus-broker|dbus-broker-lau|sshd|sshd-session|tmux|zsh)$"
      "--prefer"
      "^(\\.claude-unwrapp|node|rust-analyzer|cargo|rustc)$"
    ];
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
