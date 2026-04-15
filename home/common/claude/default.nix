{config, ...}: {
  imports = [
    ../../../modules/claude-security
    ./plugins.nix
    ./settings.nix
    ./rules.nix
    ./skills.nix
  ];

  programs.claude-code.security = {
    enable = true;
    hooks.notification.ntfy = {
      enable = true;
      topicFile = config.custom.secrets.ntfy-topic;
    };
    permissions.confirmBeforeWrite = [
      {
        tool = "mcp__filesystem__delete_file";
        reason = "This will delete a file. Confirm this is intended before proceeding.";
      }
      {
        tool = "mcp__serena__write_memory";
        reason = "Writing to persistent Serena memory.";
      }
      {
        tool = "mcp__serena__edit_memory";
        reason = "Editing persistent Serena memory.";
      }
      {
        tool = "mcp__serena__delete_memory";
        reason = "Deleting persistent Serena memory.";
      }
    ];
  };
}
