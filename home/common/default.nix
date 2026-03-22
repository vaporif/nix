{
  config,
  inputs,
  pkgs,
  lib,
  ...
}: let
  cfg = config.custom;
in {
  imports = [
    ../../modules/options.nix
    ./claude.nix
    ./git.nix
    ./ssh.nix
    ./mcp.nix
    ./qdrant.nix
    ./xdg.nix
    ./packages.nix
    ./shell.nix
    ./neovim.nix
    ./librewolf.nix
    ./sandboxed.nix
  ];

  custom.lspPackages = with pkgs; [
    lua-language-server
    typescript-language-server
    basedpyright
    nixd
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
      SOPS_AGE_KEY_FILE = "$HOME/.config/sops/age/key.txt";
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
    };

    parry-guard = {
      enable = pkgs.stdenv.isDarwin;
      package = inputs.parry-guard.packages.${pkgs.stdenv.hostPlatform.system}.default;
      hfTokenFile = "/run/secrets/hf-token-scan-injection";
      ignoreDirs = ["${cfg.homeDir}/Repos/"];
    };
  };
}
