{
  config,
  inputs,
  lib,
  ...
}: let
  cfg = config.custom;
  module = lib.modules.importApply ./neovim/module.nix inputs;
in {
  imports = [
    (inputs.wrappers.lib.getInstallModule {
      name = "neovim";
      value = module;
    })
  ];

  wrappers.neovim = {
    enable = true;
    nixConfigPath = cfg.configPath;
    inherit (cfg) lspPackages;
    rustAnalyzerCmd = [cfg.lspmux.servers.rust-analyzer.command] ++ cfg.lspmux.servers.rust-analyzer.args;
    rustAnalyzerSettings = cfg.lspmux.rustAnalyzerSettings;
    # Same gate as the GitLab MCP server (work VM only), reading the same sops
    # secrets. gitlab.nvim needs write scope for comments and approvals, which
    # is why it is not tied to the MCP server's read-only wrapper.
    gitlab = {
      inherit (cfg.gitlab) enable;
      tokenPath = lib.optionalString (cfg.secrets.gitlab-token != null) cfg.secrets.gitlab-token;
      urlPath = lib.optionalString (cfg.secrets.gitlab-api-url != null) cfg.secrets.gitlab-api-url;
    };
  };
}
