{
  pkgs,
  sharedLspPackages,
  earthtone-nvim,
  vim-tidal-lua,
  userConfig,
  wrappers,
  ...
}: let
  mkPlugin = name: src:
    pkgs.vimUtils.buildVimPlugin {
      pname = name;
      version = "unstable";
      src = src;
    };
in {
  imports = [
    (wrappers.lib.mkInstallModule {
      loc = ["home" "packages"];
      name = "neovim";
      value = wrappers.lib.wrapperModules.neovim;
    })
  ];

  wrappers.neovim = {pkgs, ...}: {
    enable = true;

    settings = {
      config_directory = ../../config/nvim;
      info_plugin_name = "nix-info";
    };

    config = {
      info.configPath = userConfig.configPath;

      specs = {
        # ── Eager: loaded before init.lua ──────────────────────
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

        # ── Eager: loaded at startup ──────────────────────────
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

        # ── Lazy: completion ──────────────────────────────────
        completion = {
          lazy = true;
          data = with pkgs.vimPlugins; [
            blink-cmp
            blink-pairs
            lazydev-nvim
          ];
        };

        # ── Lazy: treesitter ──────────────────────────────────
        treesitter = {
          lazy = true;
          collateGrammars = true;
          data = with pkgs.vimPlugins; [
            nvim-treesitter.withAllGrammars
            nvim-treesitter-textobjects
            nvim-treesitter-context
          ];
        };

        # ── Lazy: LSP & formatting ────────────────────────────
        lsp = {
          lazy = true;
          data = with pkgs.vimPlugins; [
            nvim-lspconfig
            conform-nvim
          ];
        };

        # ── Lazy: navigation ──────────────────────────────────
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

        # ── Lazy: git ─────────────────────────────────────────
        git = {
          lazy = true;
          data = with pkgs.vimPlugins; [
            gitsigns-nvim
            diffview-nvim
          ];
        };

        # ── Lazy: UI ──────────────────────────────────────────
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

        # ── Lazy: debug ──────────────────────────────────────
        debug = {
          lazy = true;
          data = with pkgs.vimPlugins; [
            nvim-dap
            nvim-dap-ui
            nvim-dap-go
            nvim-nio
          ];
        };

        # ── Lazy: testing ─────────────────────────────────────
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

        # ── Lazy: language-specific ───────────────────────────
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

        # ── Lazy: utilities ───────────────────────────────────
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

        # ── Tools (no plugin, just PATH) ─────────────────────
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
