{
  pkgs,
  sharedLspPackages,
  earthtone-nvim,
  vim-tidal-lua,
  difftastic-nvim,
  userConfig,
  wrappers,
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
    src = difftastic-nvim;
    cargoLock.lockFile = "${difftastic-nvim}/Cargo.lock";
  };

  difftastic-nvim-plugin = (mkPluginNoCheck "difftastic.nvim" difftastic-nvim).overrideAttrs (old: {
    postInstall =
      (old.postInstall or "")
      + ''
        mkdir -p $out/target/release
        cp ${difftastic-nvim-lib}/lib/libdifftastic_nvim.* $out/target/release/
        ln -sf libdifftastic_nvim.dylib $out/target/release/difftastic_nvim.so
      '';
  });
in {
  imports = [
    (wrappers.lib.mkInstallModule {
      loc = ["home" "packages"];
      name = "neovim";
      value = wrappers.lib.wrapperModules.neovim;
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

      info.configPath = userConfig.configPath;

      specMods = _: {
        options.extraPackages = lib.mkOption {
          type = lib.types.listOf wlib.types.stringable;
          default = [];
          description = "extra packages to add to PATH";
        };
      };

      extraPackages = config.specCollect (acc: v: acc ++ (v.extraPackages or [])) [];

      specs = {
        # eager: loaded before init.lua
        colorscheme = {
          data = mkPlugin "earthtone.nvim" earthtone-nvim;
          lazy = false;
          before = ["INIT_MAIN"];
        };

        lze = {
          data = pkgs.vimPlugins.lze;
          lazy = false;
          before = ["INIT_MAIN"];
        };

        # eager: loaded at startup
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

        # lazy: completion
        completion = {
          lazy = true;
          data = with pkgs.vimPlugins; [
            blink-cmp
            blink-pairs
            lazydev-nvim
          ];
        };

        # lazy: treesitter
        treesitter = {
          lazy = true;
          collateGrammars = true;
          data = with pkgs.vimPlugins; [
            nvim-treesitter.withAllGrammars
            nvim-treesitter-textobjects
            nvim-treesitter-context
          ];
        };

        # lazy: LSP & formatting
        lsp = {
          lazy = true;
          data = with pkgs.vimPlugins; [
            nvim-lspconfig
            conform-nvim
          ];
        };

        # lazy: navigation
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

        # lazy: git
        git = {
          lazy = true;
          data =
            (with pkgs.vimPlugins; [
              gitsigns-nvim
              diffview-nvim
            ])
            ++ [difftastic-nvim-plugin];
        };

        # lazy: UI
        ui = {
          lazy = true;
          data = with pkgs.vimPlugins; [
            lualine-nvim
            which-key-nvim
            noice-nvim
            alpha-nvim
            trouble-nvim
          ];
        };

        # lazy: debug
        debug = {
          lazy = true;
          data = with pkgs.vimPlugins; [
            nvim-dap
            nvim-dap-ui
            nvim-dap-go
            nvim-nio
          ];
        };

        # lazy: testing
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

        # lazy: language-specific
        go = {
          lazy = true;
          data = with pkgs.vimPlugins; [
            go-nvim
            guihua-lua
          ];
        };

        tidal = {
          lazy = true;
          data = mkPlugin "vim-tidal-lua" vim-tidal-lua;
        };

        # lazy: utilities
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

        # tools: no plugin, just PATH
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
