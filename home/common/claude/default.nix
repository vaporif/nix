{config, ...}: {
  imports = [
    ../../../modules/claude-security
    ./plugins.nix
    ./settings.nix
    ./rules.nix
  ];

  programs.claude-code.security = {
    enable = true;
    hooks.notification.ntfy = {
      enable = true;
      topicFile = config.custom.secrets.ntfy-topic;
    };
  };
}
