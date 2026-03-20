{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.custom;
  homeDir = config.home.homeDirectory;
  homebrewPath =
    if pkgs.stdenv.hostPlatform.isAarch64
    then "/opt/homebrew/bin"
    else "/usr/local/bin";
in {
  home = {
    sessionPath = [homebrewPath];
    sessionVariables = lib.optionalAttrs (cfg.sshAgent == "secretive") {
      SSH_AUTH_SOCK = "${homeDir}/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh";
    };
    # Claude Desktop reads from ~/Library/, Claude Code from /Library/ (system activation)
    file."Library/Application Support/Claude/claude_desktop_config.json".source = cfg.desktopMcpServersConfig;
  };

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
          export QDRANT__SERVICE__API_KEY="$(cat /run/secrets/qdrant-api-key)"
          exec ${pkgs.qdrant}/bin/qdrant --config-path ${homeDir}/.qdrant/config.yaml
        ''}"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "${homeDir}/.qdrant/qdrant.log";
      StandardErrorPath = "${homeDir}/.qdrant/qdrant.err";
    };
  };
}
