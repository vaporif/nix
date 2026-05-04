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
    # No sops, no topicFile, no ntfy — keeps the (enable -> topicFile != null)
    # assertion happy on a fresh fork.
    hooks.notification.ntfy = lib.mkIf (config.custom.secrets.ntfy-topic != null) {
      enable = true;
      topicFile = config.custom.secrets.ntfy-topic;
    };
    permissions.confirmBeforeWrite = [
      {
        tool = "mcp__filesystem__delete_file";
        reason = "This will delete a file. Confirm this is intended before proceeding.";
      }
    ];
  };
}
