{
  pkgs,
  config,
  inputs,
  ...
}: let
  cfg = config.custom;

  sharedLspPackages = with pkgs; [
    lua-language-server
    typescript-language-server
    basedpyright
    nixd
  ];

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
  imports = [
    (inputs.wrappers.lib.mkInstallModule {
      loc = ["home" "packages"];
      name = "neovim";
      value = inputs.wrappers.lib.wrapperModules.neovim;
    })
  ];

  wrappers.neovim = {
    config,
    pkgs,
    lib,
    wlib,
    ...
  }: {
    config = {
      enable = true;

      settings = {
        config_directory = ../../config/nvim;
        info_plugin_name = "nix-info";
      };

      info.configPath = cfg.configPath;

      specMods = _: {
        options.extraPackages = lib.mkOption {
          type = lib.types.listOf wlib.types.stringable;
          default = [];
          description = "extra packages to add to PATH";
        };
      };

      extraPackages = config.specCollect (acc: v: acc ++ (v.extraPackages or [])) [];

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
            alpha-nvim
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
            baleia-nvim
            yanky-nvim
            substitute-nvim
            outline-nvim
            grug-far-nvim
            nvim-ufo
            promise-async
            guess-indent-nvim
            render-markdown-nvim
          ];
        };

        tools = {
          data = null;
          extraPackages =
            sharedLspPackages
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
  };
}
