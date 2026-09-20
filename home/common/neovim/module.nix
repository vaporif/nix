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

  # The plugin normally shells out to `go build` on first use and drops the
  # binary in stdpath("data"). Building it here keeps the runtime read-only and
  # makes `server.binary_provided` skip the plugin's own build/version dance.
  gitlab-nvim-server = pkgs.buildGoModule {
    pname = "gitlab-nvim-server";
    version = "4.1.2";
    src = inputs.gitlab-nvim;
    vendorHash = "sha256-OLAKTdzqynBDHqWV5RzIpfc3xZDm6uYyLD4rxbh0DMg=";
    subPackages = ["cmd"];
    postInstall = "mv $out/bin/cmd $out/bin/gitlab.nvim";
  };

  gitlab-nvim-plugin = mkPluginNoCheck "gitlab.nvim" inputs.gitlab-nvim;

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

    # rust-analyzer command for rustaceanvim. Empty leaves rustaceanvim's own
    # discovery in place, which is what the standalone package wants; HM sets it
    # to the lspmux client so neovim windows share one server with each other
    # and with Claude Code. See home/common/lspmux.nix.
    rustAnalyzerCmd = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Command and args for rust-analyzer, empty to let rustaceanvim decide";
    };

    rustAnalyzerSettings = lib.mkOption {
      type = lib.types.attrs;
      default = {
        files.excludeDirs = [".direnv"];
      };
      description = "rust-analyzer settings passed to rustaceanvim";
    };

    # gitlab.nvim ships a Go server, so it is opt-in per host rather than part
    # of the baked standalone package: building it everywhere buys nothing on a
    # host that never opens a GitLab merge request.
    gitlab = {
      enable = lib.mkEnableOption "gitlab.nvim, in-editor merge-request review (discussion tree, line comments, approvals)";
      tokenPath = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Path to a file holding the GitLab personal access token. Empty falls back to GITLAB_TOKEN or a project .gitlab.nvim file.";
      };
      urlPath = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Path to a file holding the GitLab instance URL. Empty falls back to GITLAB_URL, then gitlab.com.";
      };
    };
  };

  config = {
    settings = {
      config_directory = ../../../config/nvim;
      info_plugin_name = "nix-info";
      inherit (config) rustAnalyzerCmd rustAnalyzerSettings;
      gitlab = {
        inherit (config.gitlab) enable;
        token_path = config.gitlab.tokenPath;
        url_path = config.gitlab.urlPath;
        # Only referenced when enabled, so a host without GitLab never pulls
        # the Go server into its closure.
        binary =
          if config.gitlab.enable
          then "${gitlab-nvim-server}/bin/gitlab.nvim"
          else "";
      };
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

      # nvim-lspconfig is data, not behaviour: its lsp/*.lua files are what give
      # every vim.lsp.config its filetypes and root_markers. core/lsp.lua runs
      # vim.lsp.enable at startup, so the files have to be on the runtimepath by
      # then — lazy-loading them let servers attach to any buffer at all.
      lspconfig = {
        lazy = false;
        data = pkgs.vimPlugins.nvim-lspconfig;
      };

      lsp = {
        lazy = true;
        data = pkgs.vimPlugins.conform-nvim;
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
          ++ [difftastic-nvim-plugin]
          ++ lib.optional config.gitlab.enable gitlab-nvim-plugin;
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
          image-nvim
          diagram-nvim
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
            mermaid-cli
            imagemagick
          ]);
      };
    };
  };
}
