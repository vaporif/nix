{
  lib,
  pkgs,
  config,
  inputs,
  ...
}: let
  cfg = config.custom;
  homeDir = config.home.homeDirectory;
  homebrewPath = "/opt/homebrew/bin";
in {
  imports = [
    ./sandboxed.nix
    ../common/qdrant.nix
    ../common/librewolf.nix
    inputs.mac-app-util.homeManagerModules.default
  ];

  home = {
    packages = with pkgs; [
      qbittorrent
      mpv-unwrapped
    ];
    sessionPath = [homebrewPath];
    sessionVariables =
      lib.optionalAttrs (cfg.sshAgent == "secretive") {
        SSH_AUTH_SOCK = "${homeDir}/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh";
      }
      // {
        # macOS APFS Data volume always reports MNT_EXPORTED, causing MDBX to
        # reject it as a "remote" filesystem. Allow non-readonly access.
        CFLAGS = "-DMDBX_ENABLE_NON_READONLY_EXPORT=1";
      };
    # Claude Desktop reads from ~/Library/, Claude Code from /Library/ (system activation)
    file = lib.mkIf cfg.claude.enable {
      "Library/Application Support/Claude/claude_desktop_config.json" = {
        source = cfg.desktopMcpServersConfig;
        force = true;
      };
    };
  };

  programs.zsh.initContent = ''
    unity() {
      open -a "Unity Hub" --args --projectPath "''${1:A}"
    }
  '';

  stylix.targets.librewolf.profileNames = ["default"];

  # mac-app-util skips regenerating a trampoline if the destination .app
  # already exists, so its inner wrapper script keeps pointing at the old
  # nix-store path even after a switch (e.g. LibreWolf 149 → 150 launched
  # the stale 149 binary). Wipe the trampolines dir before linkGeneration
  # so every activation rebuilds them against current store paths.
  home.activation.cleanStaleTrampolines = lib.hm.dag.entryBefore ["linkGeneration"] ''
    run rm -rf "$HOME/Applications/Home Manager Trampolines"
  '';

  programs.ssh = {
    extraOptionOverrides = lib.optionalAttrs (cfg.sshAgent == "secretive") {
      IdentityAgent = "${homeDir}/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh";
    };
    settings = lib.optionalAttrs (cfg.utmHostIp != null) {
      "personal-nixos" = {
        HostName = cfg.utmHostIp;
        User = cfg.user;
        ForwardAgent = true;
      };
    };
  };

  xdg.configFile = {
    "karabiner/karabiner.json".source = ../../config/karabiner/karabiner.json;
  };

  launchd.agents.qdrant = {
    enable = cfg.qdrant.enable;
    config = {
      Label = "org.qdrant.server";
      ProgramArguments = [
        "${pkgs.writeShellScript "qdrant-wrapper" ''
          exec ${lib.getExe' pkgs.qdrant "qdrant"} --config-path ${homeDir}/.qdrant/config.yaml
        ''}"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "${homeDir}/.qdrant/qdrant.log";
      StandardErrorPath = "${homeDir}/.qdrant/qdrant.err";
    };
  };
}
