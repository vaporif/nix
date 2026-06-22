{
  config,
  inputs,
  pkgs,
  ...
}: let
  cfg = config.custom;
in {
  programs.wezterm = {
    enable = true;
    enableZshIntegration = true;
    extraConfig = builtins.replaceStrings ["@configPath@" "@agentDeckPath@"] [cfg.configPath "${inputs.wezterm-agent-deck}/plugin/init.lua"] (builtins.readFile ../../config/wezterm/init.lua);
  };

  # GUI-launched WezTerm spawns the first shell with a minimal launchd env (no
  # TERMINFO_DIRS), so zsh's zle can't find the `wezterm` terminfo at startup —
  # hence "can't find terminal definition for wezterm" and a broken keymap until
  # a second shell inherits TERMINFO_DIRS. ~/.terminfo is the one dir ncurses
  # always searches without any env var, so mirror the entry there.
  home.file.".terminfo" = {
    source = "${pkgs.wezterm.terminfo}/share/terminfo";
    recursive = true;
  };

  xdg.configFile = {
    "yazi/yazi.toml".source = ../../config/yazi/yazi.toml;
    "yazi/init.lua".source = ../../config/yazi/init.lua;
    "yazi/keymap.toml".text = builtins.replaceStrings ["@configPath@"] [cfg.configPath] (builtins.readFile ../../config/yazi/keymap.toml);
    "yazi/plugins/yamb.yazi" = {
      source = inputs.yamb-yazi;
      recursive = true;
    };
    "yazi/plugins/yafg.yazi" = {
      source = inputs.yafg-yazi;
      recursive = true;
    };
    "yazi/plugins/augment-command.yazi" = {
      source = inputs.augment-command-yazi;
      recursive = true;
    };
    "tidal/Tidal.ghci".source = ../../config/tidal/Tidal.ghci;
    "procs/config.toml".source = ../../config/procs/config.toml;
    "wezterm/colors/earthtone-light.toml".source = "${inputs.earthtone-nvim}/extras/wezterm_light.toml";
    "wezterm/colors/earthtone-dark.toml".source = "${inputs.earthtone-nvim}/extras/wezterm_dark.toml";
  };
}
