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
    ferrex = {
      url = "github:vaporif/ferrex";
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
    mattpocock-skills = {
      url = "github:mattpocock/skills";
      flake = false;
    };
    wshobson-agents = {
      url = "github:wshobson/agents";
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
    vim-tidal = {
      url = "github:tidalcycles/vim-tidal";
      flake = false;
    };
    vim-tidal-lua = {
      url = "github:vaporif/vim-tidal-lua";
      flake = false;
    };
    go-mod-nvim = {
      url = "github:syz51/go-mod.nvim";
      flake = false;
    };

    yamb-yazi = {
      url = "github:h-hg/yamb.yazi";
      flake = false;
    };
    yafg-yazi = {
      url = "github:XYenon/yafg.yazi";
      flake = false;
    };
    augment-command-yazi = {
      url = "github:hankertrix/augment-command.yazi";
      flake = false;
    };
    wezterm-agent-deck = {
      url = "github:Eric162/wezterm-agent-deck";
      flake = false;
    };
    flake-utils.url = "github:numtide/flake-utils";
    mac-app-util = {
      url = "github:hraban/mac-app-util";
      # Don't override nixpkgs — upstream pins an older revision deliberately,
      # because their lisp deps (named-readtables, cl-interpol) regressed on
      # SBCL 2.6.x. See hraban/mac-app-util#42, NixOS/nixpkgs#491773.
      inputs.flake-utils.follows = "flake-utils";
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
    inherit (nixpkgs) lib;
    supportedSystems = ["aarch64-darwin" "aarch64-linux"];

    localPackages = import ./overlays {
      inherit (inputs) vim-tidal difftastic-src;
    };

    sharedOverlays = [inputs.mcp-nixos.overlays.default inputs.earthtone-nvim.overlays.default localPackages];

    mkPkgs = system:
      import nixpkgs {
        inherit system;
        overlays = sharedOverlays;
      };

    allowUnfreePredicate = pkg:
      builtins.elem (lib.getName pkg) [
        "spacetimedb"
        "claude-code"
        # nixpkgs bug: upstream auto-updater couldn't detect the upstream
        # license and defaulted meta.license to unfree in generated.nix.
        # Both plugins are actually permissively licensed.
        "neotest-vitest"
        "neotest-foundry"
      ];

    nixpkgsConfig = {
      nixpkgs.overlays = sharedOverlays;
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
    formatter = lib.genAttrs supportedSystems (
      system: (mkPkgs system).alejandra
    );

    checks = lib.genAttrs supportedSystems (system: let
      chkPkgs = mkPkgs system;
    in
      {
        formatting = chkPkgs.runCommand "check-formatting" {} ''
          ${chkPkgs.alejandra}/bin/alejandra -c ${./.} && touch $out
        '';
      }
      // lib.optionalAttrs chkPkgs.stdenv.isDarwin (
        chkPkgs.unclog.passthru.tests
        // chkPkgs.nomicfoundation_solidity_language_server.passthru.tests
        // chkPkgs.claude_formatter.passthru.tests
        // chkPkgs.tidal_script.passthru.tests
      )
      // lib.optionalAttrs chkPkgs.stdenv.isLinux {
        claude-security = import ./tests/claude-security.nix {
          pkgs = chkPkgs;
          inherit home-manager;
        };
        claude-settings = import ./tests/claude-settings.nix {
          pkgs = chkPkgs;
          inherit home-manager;
        };
        check-bash-matcher = import ./tests/check-bash-matcher.nix {
          pkgs = chkPkgs;
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
        inputs.mac-app-util.darwinModules.default
        ./system/darwin
        home-manager.darwinModules.home-manager
        (mkHomeManager {
          hostModule = ./hosts/macbook.nix;
          platformHome = ./home/darwin;
        })
      ];
    };

    nixosConfigurations.nixos = lib.nixosSystem {
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
