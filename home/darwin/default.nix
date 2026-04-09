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
    inputs.mac-app-util.homeManagerModules.default
  ];

  home = {
    packages = with pkgs; [
      element-desktop
      signal-desktop
      qbittorrent
      mpv
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
    file."Library/Application Support/Claude/claude_desktop_config.json".source = cfg.desktopMcpServersConfig;
  };

  stylix.targets.librewolf.profileNames = ["default"];

  programs.ssh = {
    extraOptionOverrides = lib.optionalAttrs (cfg.sshAgent == "secretive") {
      IdentityAgent = "${homeDir}/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh";
    };
    matchBlocks = lib.optionalAttrs (cfg.utmHostIp != null) {
      "utm-nixos" = {
        hostname = cfg.utmHostIp;
        inherit (cfg) user;
        forwardAgent = true;
      };
    };
  };

  xdg.configFile = {
    "karabiner/karabiner.json".source = ../../config/karabiner/karabiner.json;
  };

  launchd.agents.qdrant = {
    enable = true;
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
