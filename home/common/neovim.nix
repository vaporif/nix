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
    lspPackages = cfg.lspPackages;
  };
}
