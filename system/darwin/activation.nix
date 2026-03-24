{
  pkgs,
  config,
  ...
}: let
  cfg = config.custom;
  hmCfg = config.home-manager.users.${cfg.user}.custom;
in {
  system.activationScripts.postActivation.text = ''
    echo "Installing/updating LibreWolf..."
    ${pkgs.bash}/bin/bash ${../../scripts/install-librewolf.sh}

    # Claude apps read from /Library/ (system level), not ~/Library/
    # Symlink instead of cp to keep store paths as GC roots
    echo "Setting up MCP configs..."
    mkdir -p "/Library/Application Support/Claude"
    mkdir -p "/Library/Application Support/ClaudeCode"
    ln -sf ${hmCfg.desktopMcpServersConfig} "/Library/Application Support/Claude/claude_desktop_config.json"
    ln -sf ${hmCfg.codeMcpServersConfig} "/Library/Application Support/ClaudeCode/managed-mcp.json"

    # Restart Qdrant after sops secrets are re-deployed so it picks up the current API key
    echo "Restarting Qdrant..."
    uid=$(id -u ${cfg.user})
    launchctl kickstart -k "gui/$uid/org.qdrant.server" 2>/dev/null || true
  '';
}
