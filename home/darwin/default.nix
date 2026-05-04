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
    inputs.mac-app-util.homeManagerModules.default
  ];

  home = {
    packages = with pkgs; [
      element-desktop
      signal-desktop
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
    file."Library/Application Support/Claude/claude_desktop_config.json" = {
      source = cfg.desktopMcpServersConfig;
      force = true;
    };
  };

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
