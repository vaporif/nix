{
  config,
  lib,
  ...
}: {
  imports = [
    ../../../modules/claude-security
    ./plugins.nix
    ./settings.nix
    ./rules.nix
    ./skills.nix
  ];

  programs.claude-code.security = {
    enable = true;
    hooks.readOnce.enable = false;
    # ntfy needs a topicFile; skip the whole block when sops isn't configured
    # so the assertion (enable -> topicFile != null) doesn't trip.
    hooks.notification.ntfy = lib.mkIf (config.custom.secrets.ntfy-topic != null) {
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
