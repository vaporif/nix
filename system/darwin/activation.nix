{
  pkgs,
  config,
  ...
}: let
  cfg = config.custom;
  mcpConfig = config.home-manager.users.${cfg.user}.custom.mcpServersConfig;
in {
  system.activationScripts.postActivation.text = ''
    echo "Installing/updating LibreWolf..."
    ${pkgs.bash}/bin/bash ${../../scripts/install-librewolf.sh}

    # Claude apps read from /Library/ (system level), not ~/Library/
    # Symlink instead of cp to keep store paths as GC roots
    echo "Setting up MCP configs..."
    mkdir -p "/Library/Application Support/Claude"
    mkdir -p "/Library/Application Support/ClaudeCode"
    ln -sf ${mcpConfig} "/Library/Application Support/Claude/claude_desktop_config.json"
    ln -sf ${mcpConfig} "/Library/Application Support/ClaudeCode/managed-mcp.json"
  '';
}
