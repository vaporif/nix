# macOS-specific home-manager config
{
  lib,
  pkgs,
  homeDir,
  mcpServersConfig,
  userConfig,
  ...
}: let
  homebrewPath =
    if pkgs.stdenv.hostPlatform.isAarch64
    then "/opt/homebrew/bin"
    else "/usr/local/bin";
in {
  home = {
    sessionPath = [homebrewPath];
    sessionVariables = lib.optionalAttrs (userConfig.sshAgent == "secretive") {
      SSH_AUTH_SOCK = "${homeDir}/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh";
    };
    file."Library/Application Support/Claude/claude_desktop_config.json".source = mcpServersConfig;
  };

  programs.ssh = {
    extraOptionOverrides = lib.optionalAttrs (userConfig.sshAgent == "secretive") {
      IdentityAgent = "${homeDir}/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh";
    };
    matchBlocks = lib.optionalAttrs ((userConfig.utmHostIp or "") != "") {
      "utm-nixos" = {
        hostname = userConfig.utmHostIp;
        inherit (userConfig) user;
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
        "${pkgs.qdrant}/bin/qdrant"
        "--config-path"
        "${homeDir}/.qdrant/config.yaml"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "${homeDir}/.qdrant/qdrant.log";
      StandardErrorPath = "${homeDir}/.qdrant/qdrant.err";
    };
  };
}
