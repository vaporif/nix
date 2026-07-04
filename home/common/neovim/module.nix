# Shared neovim wrapper module. Consumed two ways:
#   - home/common/neovim.nix → getInstallModule (HM/NixOS), host injects nixConfigPath + lspPackages
#   - flake.nix              → evalModule, standalone `nix run` package using the baked defaults
inputs: {
  config,
  pkgs,
  lib,
  wlib,
  ...
}: let
  mkPlugin = name: src:
    pkgs.vimUtils.buildVimPlugin {
      pname = name;
      version = "unstable";
      inherit src;
    };

  mkPluginNoCheck = name: src:
    pkgs.vimUtils.buildVimPlugin {
      pname = name;
      version = "unstable";
      inherit src;
      doCheck = false;
    };

  difftastic-nvim-lib = pkgs.rustPlatform.buildRustPackage {
    pname = "difftastic-nvim-lib";
    version = "unstable";
    src = inputs.difftastic-nvim;
    cargoLock.lockFile = "${inputs.difftastic-nvim}/Cargo.lock";
  };

  difftastic-nvim-plugin = (mkPluginNoCheck "difftastic.nvim" inputs.difftastic-nvim).overrideAttrs (old: {
    postInstall =
      (old.postInstall or "")
      + ''
        mkdir -p $out/target/release
        cp ${difftastic-nvim-lib}/lib/libdifftastic_nvim.* $out/target/release/
        local lib=$(basename $out/target/release/libdifftastic_nvim.*)
        ln -sf "$lib" $out/target/release/difftastic_nvim.so
      '';
  });
in {
  imports = [wlib.wrapperModules.neovim];

  options = {
    # Absolute path to this repo on the host, used for the "go to nix" keymap.
    # Empty when run standalone (`nix run`) — there is no host checkout then.
    nixConfigPath = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Absolute path to the nix config repo on the host";
    };

    # LSP servers placed on PATH. Baked default keeps the standalone package
    # self-contained; HM overrides with the shared config.custom.lspPackages.
    lspPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = with pkgs; [
        lua-language-server
        typescript-language-server
        basedpyright
        nixd
      ];
      description = "LSP packages to add to neovim's PATH";
    };
  };

  config = {
    settings = {
      config_directory = ../../../config/nvim;
      info_plugin_name = "nix-info";
    };

    info.configPath = config.nixConfigPath;

    specMods = _: {
      options.runtimePkgs = lib.mkOption {
        type = lib.types.listOf wlib.types.stringable;
        default = [];
        description = "extra packages to add to PATH";
      };
    };

    runtimePkgs = config.specCollect (acc: v: acc ++ (v.runtimePkgs or [])) [];

    specs = {
      colorscheme = {
        data = pkgs.vimPlugins.earthtone-nvim;
        lazy = false;
        before = ["INIT_MAIN"];
      };

      lze = {
        data = pkgs.vimPlugins.lze;
        lazy = false;
        before = ["INIT_MAIN"];
      };

      snacks = {
        data = pkgs.vimPlugins.snacks-nvim;
        lazy = false;
      };

      rustaceanvim = {
        data = pkgs.vimPlugins.rustaceanvim;
        lazy = false;
      };

      roslyn = {
        lazy = true;
        data = pkgs.vimPlugins.roslyn-nvim;
      };

      auto-session = {
        data = pkgs.vimPlugins.auto-session;
        lazy = false;
      };

      completion = {
        lazy = true;
        data = with pkgs.vimPlugins; [
          blink-cmp
          blink-pairs
          lazydev-nvim
        ];
      };

      treesitter = {
        lazy = true;
        collateGrammars = true;
        data = with pkgs.vimPlugins; [
          nvim-treesitter.withAllGrammars
          nvim-treesitter-textobjects
          nvim-treesitter-context
        ];
      };

      lsp = {
        lazy = true;
        data = with pkgs.vimPlugins; [
          nvim-lspconfig
          conform-nvim
        ];
      };

      navigation = {
        lazy = true;
        data = with pkgs.vimPlugins; [
          fzf-lua
          neo-tree-nvim
          flash-nvim
          harpoon2
          nvim-web-devicons
          plenary-nvim
          nui-nvim
        ];
      };

      git = {
        lazy = true;
        data =
          (with pkgs.vimPlugins; [
            gitsigns-nvim
            diffview-nvim
          ])
          ++ [difftastic-nvim-plugin];
      };

      ui = {
        lazy = true;
        data = with pkgs.vimPlugins; [
          lualine-nvim
          which-key-nvim
          noice-nvim
          nvim-navic
        ];
      };

      debug = {
        lazy = true;
        data = with pkgs.vimPlugins; [
          nvim-dap
          nvim-dap-ui
          nvim-dap-go
          nvim-nio
        ];
      };

      testing = {
        lazy = true;
        data = with pkgs.vimPlugins; [
          neotest
          neotest-golang
          neotest-python
          neotest-vitest
          neotest-foundry
        ];
      };

      tidal = {
        lazy = true;
        data = mkPlugin "vim-tidal-lua" inputs.vim-tidal-lua;
      };

      utilities = {
        lazy = true;
        data = with pkgs.vimPlugins; [
          mini-nvim
          marks-nvim
          todo-comments-nvim
          nvim-early-retirement
          crates-nvim
          ((mkPlugin "go-mod.nvim" inputs.go-mod-nvim).overrideAttrs {
            dependencies = [pkgs.vimPlugins.plenary-nvim];
          })
          baleia-nvim
          yanky-nvim
          substitute-nvim
          outline-nvim
          grug-far-nvim
          nvim-ufo
          promise-async
          inc-rename-nvim
          guess-indent-nvim
          render-markdown-nvim
        ];
      };

      tools = {
        data = null;
        runtimePkgs =
          config.lspPackages
          ++ (with pkgs; [
            lua51Packages.luarocks
            lua51Packages.lua
            stylua
            haskell-language-server
            just-lsp
            golangci-lint
          ]);
      };
    };
  };
}
