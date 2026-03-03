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
    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mcp-servers-nix = {
      url = "github:vaporif/mcp-servers-nix/qdrant";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mcp-nixos.url = "github:utensils/mcp-nixos";
    sops-nix.url = "github:Mic92/sops-nix";
    fzf-git-sh = {
      url = "https://raw.githubusercontent.com/junegunn/fzf-git.sh/c823ffd521cb4a3a65a5cf87f1b1104ef651c3de/fzf-git.sh";
      flake = false;
    };
    yamb-yazi = {
      url = "github:h-hg/yamb.yazi/22af0033be18eead7b04c2768767d38ccfbaa05b";
      flake = false;
    };
    vim-tidal = {
      url = "github:tidalcycles/vim-tidal/e440fe5bdfe07f805e21e6872099685d38e8b761";
      flake = false;
    };
    claude-code-plugins = {
      url = "github:anthropics/claude-plugins-official";
      flake = false;
    };
    superpowers = {
      url = "github:obra/superpowers/e4a2375cb705ca5800f0833528ce36a3faf9017a";
      flake = false;
    };
    earthtone-nvim = {
      url = "github:vaporif/earthtone.nvim";
      flake = false;
    };
    nix-devshells.url = "github:vaporif/nix-devshells";
    parry = {
      url = "github:vaporif/parry";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    nix-darwin,
    mcp-nixos,
    home-manager,
    sops-nix,
    fzf-git-sh,
    yamb-yazi,
    vim-tidal,
    mcp-servers-nix,
    stylix,
    claude-code-plugins,
    superpowers,
    earthtone-nvim,
    nix-devshells,
    parry,
    ...
  }: let
    hosts = {
      macbook = import ./hosts/macbook.nix;
      nixos = import ./hosts/nixos.nix;
    };

    supportedSystems = ["aarch64-darwin" "aarch64-linux"];

    localPackages = import ./overlays {inherit vim-tidal;};

    mkPkgs = system:
      import nixpkgs {
        inherit system;
        overlays = [localPackages];
      };

    mkHomeDir = pkgs: user:
      if pkgs.stdenv.isDarwin
      then "/Users/${user}"
      else "/home/${user}";

    # TODO: revert once nix rs is fixed https://github.com/oraios/serena/issues/800
    serenaSrc = {
      owner = "vaporif";
      repo = "serena";
      rev = "0f65275856f14fbf4827e3327ee8f132ea58b156";
      hash = "sha256-fhlrO1mJYdevYVrJ02t5v3I2fiuclJRQSRinufwka+w=";
    };

    allowUnfreePredicate = pkg:
      builtins.elem (nixpkgs.lib.getName pkg) [
        "spacetimedb"
        "claude-code"
      ];

    # Build all derived values for a host
    mkHostContext = hostConfig:
      assert builtins.isString hostConfig.user;
      assert builtins.isString hostConfig.hostname;
      assert builtins.elem hostConfig.system ["aarch64-darwin" "aarch64-linux"];
      assert builtins.isString hostConfig.configPath; let
        pkgs = mkPkgs hostConfig.system;
        homeDir = mkHomeDir pkgs hostConfig.user;
        sharedLspPackages = with pkgs; [
          lua-language-server
          typescript-language-server
          basedpyright
          nixd
        ];
        serenaPatched = mcp-servers-nix.packages.${hostConfig.system}.serena.overrideAttrs (_: {
          version = "0.1.4-unstable-2025-12-28";
          src = pkgs.fetchFromGitHub serenaSrc;
        });
        fzf-git-sh-package = pkgs.writeShellScriptBin "fzf-git.sh" (builtins.readFile fzf-git-sh);
        mcp-nixos-package = mcp-nixos.packages.${hostConfig.system}.default;
        mcpConfig = import ./mcp.nix {
          inherit pkgs homeDir serenaPatched mcp-servers-nix mcp-nixos-package sharedLspPackages;
          userConfig = hostConfig;
        };
        mcpServersConfig = mcp-servers-nix.lib.mkConfig pkgs mcpConfig;
      in {
        inherit pkgs homeDir sharedLspPackages mcpServersConfig fzf-git-sh-package mcp-nixos-package;
      };

    darwinCtx = mkHostContext hosts.macbook;
    linuxCtx = mkHostContext hosts.nixos;
  in {
    formatter = nixpkgs.lib.genAttrs supportedSystems (
      system:
        (mkPkgs system).alejandra
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

    darwinConfigurations.${hosts.macbook.hostname} = nix-darwin.lib.darwinSystem {
      inherit (hosts.macbook) system;
      specialArgs = {
        inherit (hosts.macbook) user;
        inherit (darwinCtx) homeDir mcpServersConfig;
        inherit earthtone-nvim;
        userConfig = hosts.macbook;
      };
      modules = [
        {
          nixpkgs.overlays = [localPackages];
          nixpkgs.config.allowUnfreePredicate = allowUnfreePredicate;
        }
        stylix.darwinModules.stylix
        sops-nix.darwinModules.sops
        ./system/darwin
        home-manager.darwinModules.home-manager
        {
          users.users.${hosts.macbook.user} = {
            name = hosts.macbook.user;
            home = darwinCtx.homeDir;
          };
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = {
              inherit (hosts.macbook) user;
              inherit (darwinCtx) homeDir sharedLspPackages mcpServersConfig fzf-git-sh-package mcp-nixos-package;
              inherit yamb-yazi claude-code-plugins superpowers nix-devshells earthtone-nvim parry;
              userConfig = hosts.macbook;
            };
            users.${hosts.macbook.user} = {
              imports = [
                ./home/common
                ./home/darwin
                parry.homeManagerModules.default
              ];
            };
            backupFileExtension = "backup";
          };
        }
      ];
    };

    nixosConfigurations.${hosts.nixos.hostname} = nixpkgs.lib.nixosSystem {
      inherit (hosts.nixos) system;
      specialArgs = {
        inherit (hosts.nixos) user;
        inherit (linuxCtx) homeDir mcpServersConfig;
        inherit earthtone-nvim;
        userConfig = hosts.nixos;
      };
      modules = [
        {
          nixpkgs.overlays = [localPackages];
          nixpkgs.config.allowUnfreePredicate = allowUnfreePredicate;
        }
        stylix.nixosModules.stylix
        ./system/nixos
        home-manager.nixosModules.home-manager
        {
          users.users.${hosts.nixos.user} = {
            name = hosts.nixos.user;
            home = linuxCtx.homeDir;
            isNormalUser = true;
            extraGroups = ["wheel"];
          };
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = {
              inherit (hosts.nixos) user;
              inherit (linuxCtx) homeDir sharedLspPackages mcpServersConfig fzf-git-sh-package mcp-nixos-package;
              inherit yamb-yazi claude-code-plugins superpowers nix-devshells earthtone-nvim parry;
              userConfig = hosts.nixos;
            };
            users.${hosts.nixos.user} = {
              imports = [
                ./home/common
                ./home/linux
                parry.homeManagerModules.default
              ];
            };
            backupFileExtension = "backup";
          };
        }
      ];
    };
  };
}
