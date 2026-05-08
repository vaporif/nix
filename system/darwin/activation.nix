{config, ...}: let
  cfg = config.custom;
  hmCfg = config.home-manager.users.${cfg.user}.custom;
in {
  system.activationScripts.postActivation.text =
    if hmCfg.claude.enable
    then ''
      # Claude apps read from /Library/ (system level), not ~/Library/
      # Symlink instead of cp to keep store paths as GC roots
      echo "Setting up MCP configs..."
      mkdir -p "/Library/Application Support/Claude"
      mkdir -p "/Library/Application Support/ClaudeCode"
      ln -sf ${hmCfg.desktopMcpServersConfig} "/Library/Application Support/Claude/claude_desktop_config.json"
      ln -sf ${hmCfg.codeMcpServersConfig} "/Library/Application Support/ClaudeCode/managed-mcp.json"
    ''
    else ''
      # Claude disabled — remove any leftover symlinks from a previous activation
      rm -f "/Library/Application Support/Claude/claude_desktop_config.json"
      rm -f "/Library/Application Support/ClaudeCode/managed-mcp.json"
    '';
}
