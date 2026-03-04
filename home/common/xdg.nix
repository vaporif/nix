{
  config,
  inputs,
  ...
}: let
  cfg = config.custom;
in {
  programs.wezterm = {
    enable = true;
    enableZshIntegration = true;
    extraConfig = builtins.replaceStrings ["@configPath@"] [cfg.configPath] (builtins.readFile ../../config/wezterm/init.lua);
  };

  xdg.configFile = {
    "yazi/yazi.toml".source = ../../config/yazi/yazi.toml;
    "yazi/init.lua".source = ../../config/yazi/init.lua;
    "yazi/keymap.toml".text = builtins.replaceStrings ["@configPath@"] [cfg.configPath] (builtins.readFile ../../config/yazi/keymap.toml);
    "yazi/plugins/yamb.yazi" = {
      source = inputs.yamb-yazi;
      recursive = true;
    };
    "tidal/Tidal.ghci".source = ../../config/tidal/Tidal.ghci;
    "procs/config.toml".source = ../../config/procs/config.toml;
    "wezterm/colors/earthtone-light.toml".source = "${inputs.earthtone-nvim}/extras/wezterm_light.toml";
    "wezterm/colors/earthtone-dark.toml".source = "${inputs.earthtone-nvim}/extras/wezterm_dark.toml";
  };
}
