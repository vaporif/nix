{
  config,
  inputs,
  pkgs,
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
    };
    file = {
      ".envrc".text = ''
        use flake "github:vaporif/nix-devshells/${inputs.nix-devshells.rev}"
      '';
    };
  };

  programs = {
    home-manager.enable = true;

    parry = {
      enable = true;
      package = inputs.parry.packages.${pkgs.system}.onnx;
      hfTokenFile = "/run/secrets/hf-token-scan-injection";
      ignorePaths = ["${cfg.homeDir}/Repos/parry" cfg.configPath "${cfg.homeDir}/Repos/mcp-server-qdrant"];
    };
  };
}
