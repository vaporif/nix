{
  config,
  lib,
  ...
}: let
  cfg = config.custom;
in {
  imports = [
    ./security
    ./home/plugins.nix
    ./home/settings.nix
    ./home/rules.nix
    ./home/skills.nix
    ./home/agents.nix
  ];

  programs.claude-code.security = lib.mkIf cfg.claude.enable {
    enable = true;
    hooks.readOnce.enable = false;
    # No sops, no topicFile, no ntfy — keeps the (enable -> topicFile != null)
    # assertion happy on a fresh fork.
    hooks.notification.ntfy = lib.mkIf (cfg.secrets.ntfy-topic != null) {
      enable = true;
      topicFile = cfg.secrets.ntfy-topic;
    };
    permissions.confirmBeforeWrite = [
      {
        tool = "mcp__filesystem__delete_file";
        reason = "This will delete a file. Confirm this is intended before proceeding.";
      }
    ];
  };
}
