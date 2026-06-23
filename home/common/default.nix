{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.custom;
in {
  imports = [
    ./llm
    ../../claude/home.nix
    ./codex
    ./git.nix
    ./ssh.nix
    ./mcp.nix
    ./xdg.nix
    ./packages.nix
    ./shell.nix
    ./neovim.nix
    ./sandboxed.nix
  ];

  custom.lspPackages = [
    pkgs.lua-language-server
    pkgs.typescript-language-server
    pkgs.basedpyright
    pkgs.nixd
  ];

  manual = {
    manpages.enable = false;
    html.enable = false;
    json.enable = false;
  };

  home = {
    homeDirectory = cfg.homeDir;
    username = cfg.user;
    stateVersion = "24.05";
    sessionPath = [
      "$HOME/.cargo/bin"
    ];
    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      ENABLE_LSP_TOOL = "1";
      DFT_GRAPH_LIMIT = "500000";
      DFT_BYTE_LIMIT = "1000000";
    };
    file = {
      ".envrc".text = ''
        use flake "github:vaporif/nix-devshells/${inputs.nix-devshells.rev}"
      '';
    };
  };

  programs = {
    home-manager.enable = true;

    tmux = {
      enable = true;
      prefix = "C-a";
      baseIndex = 1;
      terminal = "tmux-256color";
      extraConfig = ''
        set -g pane-base-index 1
        set -g renumber-windows on
        set -ga terminal-overrides ",*256col*:Tc"
        set -ga terminal-features ",*:RGB"
        set -ga terminal-overrides ',*:Ss=\E[%p1%d q:Se=\E[ q'
      '';
    };

    parry-guard =
      {
        enable = pkgs.stdenv.isDarwin;
        package = inputs.parry-guard.packages.${pkgs.stdenv.hostPlatform.system}.default;
        ignoreDirs = ["${cfg.homeDir}/Repos/"];
      }
      // lib.optionalAttrs (cfg.secrets.hf-token-scan-injection != null) {
        hfTokenFile = cfg.secrets.hf-token-scan-injection;
      };
  };
}
