{
  description = "Cross-platform Nix configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-devshells = {
      url = "github:vaporif/nix-devshells";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    parry-guard = {
      url = "github:vaporif/parry-guard";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mcp-servers-nix = {
      url = "github:natsukium/mcp-servers-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mcp-server-qdrant = {
      url = "github:vaporif/mcp-server-qdrant";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mcp-nixos = {
      url = "github:utensils/mcp-nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mcp-youtube = {
      url = "github:vaporif/mcp-server-youtube";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sandnix = {
      url = "github:srid/sandnix";
    };

    claude-code-plugins = {
      url = "github:anthropics/claude-plugins-official";
      flake = false;
    };
    superpowers = {
      url = "github:obra/superpowers";
      flake = false;
    };
    humanizer = {
      url = "github:blader/humanizer";
      flake = false;
    };
    napkin = {
      url = "github:blader/napkin";
      flake = false;
    };
    wshobson-agents = {
      url = "github:vaporif/agents/agent-teams-proper-tool-names";
      flake = false;
    };

    wrappers = {
      url = "github:BirdeeHub/nix-wrapper-modules";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    earthtone-nvim = {
      url = "github:vaporif/earthtone.nvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    difftastic-nvim = {
      url = "github:clabby/difftastic.nvim";
      flake = false;
    };
    difftastic-src = {
      url = "github:Wilfred/difftastic";
      flake = false;
    };
    visual-explainer = {
      url = "github:nicobailon/visual-explainer";
      flake = false;
    };
    vim-tidal = {
      url = "github:tidalcycles/vim-tidal";
      flake = false;
    };
    vim-tidal-lua = {
      url = "github:vaporif/vim-tidal-lua";
      flake = false;
    };

    yamb-yazi = {
      url = "github:h-hg/yamb.yazi";
      flake = false;
    };
    wezterm-agent-deck = {
      url = "github:Eric162/wezterm-agent-deck";
      flake = false;
    };
  };

  outputs = inputs @ {
    nixpkgs,
    nix-darwin,
    home-manager,
    stylix,
    sops-nix,
    parry-guard,
    ...
  }: let
    supportedSystems = ["aarch64-darwin" "aarch64-linux"];

    localPackages = import ./overlays {
      inherit (inputs) vim-tidal difftastic-src;
    };

    mkPkgs = system:
      import nixpkgs {
        inherit system;
        overlays = [localPackages inputs.earthtone-nvim.overlays.default];
      };

    allowUnfreePredicate = pkg:
      builtins.elem (nixpkgs.lib.getName pkg) [
        "spacetimedb"
        "claude-code"
      ];

    nixpkgsConfig = {
      nixpkgs.overlays = [localPackages inputs.earthtone-nvim.overlays.default];
      nixpkgs.config.allowUnfreePredicate = allowUnfreePredicate;
    };

    mkHomeManager = {
      hostModule,
      platformHome,
    }: {config, ...}: let
      cfg = config.custom;
    in {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        extraSpecialArgs = {inherit inputs;};
        users.${cfg.user}.imports = [
          ./modules/options.nix
          hostModule
          ./home/common
          platformHome
          parry-guard.homeManagerModules.default
        ];
        backupFileExtension = "backup";
      };
    };
  in {
    formatter = nixpkgs.lib.genAttrs supportedSystems (
      system: (mkPkgs system).alejandra
    );

    checks = nixpkgs.lib.genAttrs supportedSystems (system: let
      chkPkgs = mkPkgs system;
    in
      {
        formatting = chkPkgs.runCommand "check-formatting" {} ''
          ${chkPkgs.alejandra}/bin/alejandra -c ${./.} && touch $out
        '';
      }
      // nixpkgs.lib.optionalAttrs chkPkgs.stdenv.isDarwin (
        chkPkgs.unclog.passthru.tests
        // chkPkgs.nomicfoundation_solidity_language_server.passthru.tests
        // chkPkgs.claude_formatter.passthru.tests
        // chkPkgs.tidal_script.passthru.tests
      )
      // nixpkgs.lib.optionalAttrs chkPkgs.stdenv.isLinux {
        claude-security = import ./tests/claude-security.nix {
          pkgs = chkPkgs;
          inherit home-manager;
        };
        claude-settings = import ./tests/claude-settings.nix {
          pkgs = chkPkgs;
          inherit home-manager;
        };
        xdg-config-paths = import ./tests/xdg-config-paths.nix {
          pkgs = chkPkgs;
          inherit home-manager inputs;
        };
      });

    darwinConfigurations.burnedapple = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      specialArgs = {inherit inputs;};
      modules = [
        nixpkgsConfig
        ./modules/options.nix
        ./hosts/macbook.nix
        stylix.darwinModules.stylix
        sops-nix.darwinModules.sops
        ./system/darwin
        home-manager.darwinModules.home-manager
        (mkHomeManager {
          hostModule = ./hosts/macbook.nix;
          platformHome = ./home/darwin;
        })
      ];
    };

    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = {inherit inputs;};
      modules = [
        nixpkgsConfig
        ./modules/options.nix
        ./hosts/nixos.nix
        stylix.nixosModules.stylix
        sops-nix.nixosModules.sops
        ./system/nixos
        home-manager.nixosModules.home-manager
        (mkHomeManager {
          hostModule = ./hosts/nixos.nix;
          platformHome = ./home/linux;
        })
      ];
    };
  };
}
