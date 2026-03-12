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
    parry = {
      url = "github:vaporif/parry";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mcp-servers-nix = {
      url = "github:vaporif/mcp-servers-nix/qdrant";
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
    claude-code-plugins = {
      url = "github:anthropics/claude-plugins-official";
      flake = false;
    };
    superpowers = {
      url = "github:obra/superpowers";
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
    parry,
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
      ));

    darwinConfigurations.MacBook-Pro = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      specialArgs = {inherit inputs;};
      modules = [
        {
          nixpkgs.overlays = [localPackages inputs.earthtone-nvim.overlays.default];
          nixpkgs.config.allowUnfreePredicate = allowUnfreePredicate;
        }
        ./hosts/macbook.nix
        stylix.darwinModules.stylix
        sops-nix.darwinModules.sops
        ./system/darwin
        home-manager.darwinModules.home-manager
        ({config, ...}: let
          cfg = config.custom;
        in {
          users.users.${cfg.user} = {
            name = cfg.user;
            home = "/Users/${cfg.user}";
          };
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = {inherit inputs;};
            users.${cfg.user}.imports = [
              ./hosts/macbook.nix
              ./home/common
              ./home/darwin
              parry.homeManagerModules.default
            ];
            backupFileExtension = "backup";
          };
        })
      ];
    };

    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = {inherit inputs;};
      modules = [
        {
          nixpkgs.overlays = [localPackages inputs.earthtone-nvim.overlays.default];
          nixpkgs.config.allowUnfreePredicate = allowUnfreePredicate;
        }
        ./hosts/nixos.nix
        stylix.nixosModules.stylix
        sops-nix.nixosModules.sops
        ./system/nixos
        home-manager.nixosModules.home-manager
        ({config, ...}: let
          cfg = config.custom;
        in {
          users.users.${cfg.user} = {
            name = cfg.user;
            home = "/home/${cfg.user}";
            isNormalUser = true;
            extraGroups = ["wheel"];
          };
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = {inherit inputs;};
            users.${cfg.user}.imports = [
              ./hosts/nixos.nix
              ./home/common
              ./home/linux
              parry.homeManagerModules.default
            ];
            backupFileExtension = "backup";
          };
        })
      ];
    };
  };
}
