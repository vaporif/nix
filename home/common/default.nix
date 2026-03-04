{
  config,
  inputs,
  pkgs,
  ...
}: let
  cfg = config.custom;
  homeDir =
    if pkgs.stdenv.isDarwin
    then "/Users/${cfg.user}"
    else "/home/${cfg.user}";
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
  ];

  manual = {
    manpages.enable = false;
    html.enable = false;
    json.enable = false;
  };

  home = {
    homeDirectory = homeDir;
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
      ".librewolf/librewolf.overrides.cfg".source = ../../config/librewolf/librewolf.overrides.cfg;
    };
  };

  programs = {
    home-manager.enable = true;

    parry = {
      enable = true;
      package = inputs.parry.packages.${pkgs.system}.onnx;
      hfTokenFile = "/run/secrets/hf-token-scan-injection";
      ignorePaths = ["${homeDir}/Repos/parry" cfg.configPath "${homeDir}/Repos/mcp-server-qdrant"];
    };
  };
}
