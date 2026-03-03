{
  pkgs,
  config,
  user,
  homeDir,
  sharedLspPackages,
  yamb-yazi,
  mcpServersConfig,
  claude-code-plugins,
  superpowers,
  nix-devshells,
  earthtone-nvim,
  parry,
  userConfig,
  ...
}: let
  claudePluginsBase = ".claude/plugins/marketplaces";
  nixPluginsPath = "${claudePluginsBase}/nix-plugins";

  # Marketplace manifest for Nix-managed plugins
  nixPluginsMarketplace = builtins.toJSON {
    "$schema" = "https://anthropic.com/claude-code/marketplace.schema.json";
    name = "nix-plugins";
    description = "Nix-managed Claude Code plugins";
    owner = {
      name = "nix";
      email = "nix@localhost";
    };
    plugins = [
      {
        name = "feature-dev";
        description = "Comprehensive feature development workflow";
        source = "./feature-dev";
      }
      {
        name = "ralph-wiggum";
        description = "Iterative development loops";
        source = "./ralph-wiggum";
      }
      {
        name = "code-review";
        description = "Multi-agent PR code review";
        source = "./code-review";
      }
      {
        name = "superpowers";
        description = "Core skills: TDD, debugging, collaboration patterns";
        source = "./superpowers";
      }
    ];
  };

  # Register marketplaces (preserving claude-plugins-official + adding nix-plugins)
  knownMarketplaces = builtins.toJSON {
    "claude-plugins-official" = {
      source = {
        source = "github";
        repo = "anthropics/claude-plugins-official";
      };
      installLocation = "${config.home.homeDirectory}/${claudePluginsBase}/claude-plugins-official";
      lastUpdated = "2025-01-01T00:00:00.000Z";
    };
    "nix-plugins" = {
      source = {
        source = "directory";
        path = "${config.home.homeDirectory}/${nixPluginsPath}";
      };
      installLocation = "${config.home.homeDirectory}/${nixPluginsPath}";
      lastUpdated = "2025-01-01T00:00:00.000Z";
    };
  };
in {
  imports = [
    ./packages.nix
    ./shell.nix
  ];

  # Disable manual generation to avoid builtins.toFile warning (home-manager#7935)
  manual = {
    manpages.enable = false;
    html.enable = false;
    json.enable = false;
  };

  home = {
    homeDirectory = homeDir;
    username = user;
    stateVersion = "24.05";
    sessionPath = [
      "$HOME/.cargo/bin"
    ];
    sessionVariables = {
      SOPS_AGE_KEY_FILE = "$HOME/.config/sops/age/key.txt";
      EDITOR = "nvim";
      VISUAL = "nvim";
    };
  };

  programs = {
    home-manager.enable = true;

    gh = {
      enable = true;
      extensions = [pkgs.gh-dash];
      settings.aliases = {
        co = "pr checkout";
        pv = "pr view --web";
        pl = "pr list";
        ps = "pr status";
        pm = "pr merge";
        d = "dash";
      };
    };
    lazygit = {
      enable = true;
      settings = {
        gui.nerdFontsVersion = "3";
        git.pull.mode = "ff-only";
        git.pagers = [
          {
            applyToPager = "diff";
            pager = "delta --paging=never";
            colorArg = "always";
          }
        ];
      };
    };

    wezterm = {
      enable = true;
      enableZshIntegration = true;
      # @configPath@ placeholder in init.lua is replaced with userConfig.configPath at build time
      extraConfig = builtins.replaceStrings ["@configPath@"] [userConfig.configPath] (builtins.readFile ../../config/wezterm/init.lua);
    };

    git = {
      enable = true;
      ignores = [".direnv" ".serena" ".claude" "CLAUDE.md" ".serena.bak" ".claude.bak" ".envrc.bak" ".parry-guard.redb" "CLAUDE.md.bak"];
      settings = {
        user = {
          inherit (userConfig.git) name email;
        };
        core = {
          editor = "nvim";
          pager = "delta";
        };
        alias = {
          co = "checkout";
          cob = "checkout -b";
          discard = "reset HEAD --hard";
          fp = "fetch --all --prune";
          bclone = "!git-bare-clone";
        };
        pull.ff = "only";
        push.autoSetupRemote = true;
        gui.encoding = "utf-8";
        merge.conflictstyle = "diff3";
        init.defaultBranch = "main";
        init.defaultRefFormat = "files";
        rebase.autosquash = true;
        rebase.autostash = true;
        commit.verbose = true;
        diff.external = "difft";
        diff.algorithm = "histogram";
        feature.experimental = true;
        help.autocorrect = "prompt";
        branch.sort = "committerdate";
        interactive.diffFilter = "delta --color-only";
        delta = {
          navigate = true;
          syntax-theme = "gruvbox-light";
          line-numbers = true;
        };
      };
      signing = {
        key = "${homeDir}/.ssh/signing_key.pub";
        signByDefault = userConfig.git.signingKey != "";
        format = "ssh";
      };
      # Note: "gpg.ssh" is git's config namespace for SSH signing, not GPG
      settings.gpg.ssh.allowedSignersFile = "${homeDir}/.ssh/allowed_signers";
      maintenance.enable = true;
    };

    neovim = {
      viAlias = true;
      enable = true;
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

    parry = {
      enable = true;
      package = parry.packages.${pkgs.stdenv.hostPlatform.system}.onnx;
      hfTokenFile = "/run/secrets/hf-token-scan-injection";
      ignorePaths = ["${homeDir}/Repos/parry" userConfig.configPath];
    };

    ssh = {
      enable = true;
      enableDefaultConfig = false;
      extraOptionOverrides = {
        StrictHostKeyChecking = "accept-new";
      };
      matchBlocks."*" = {
        addKeysToAgent = "yes";
        serverAliveInterval = 60;
        serverAliveCountMax = 3;
      };
    };
  };

  home.file = {
    ".envrc".text = ''
      use flake "github:vaporif/nix-devshells/${nix-devshells.rev}"
    '';
    # Qdrant config - localhost only
    ".qdrant/config.yaml".text = ''
      service:
        host: 127.0.0.1
        http_port: 6333
        grpc_port: 6334
      storage:
        storage_path: ${homeDir}/.qdrant/storage
        snapshots_path: ${homeDir}/.qdrant/snapshots
      telemetry_disabled: true
    '';
    # Stable symlink to Neovim runtime for .luarc.json
    ".local/share/nvim-runtime".source = "${pkgs.neovim-unwrapped}/share/nvim/runtime";
    ".librewolf/librewolf.overrides.cfg" = {
      source = ../../config/librewolf/librewolf.overrides.cfg;
    };
    "${config.xdg.configHome}/mcphub/servers.json".source = mcpServersConfig;

    # Claude Code plugins - create a local marketplace structure
    "${nixPluginsPath}/.claude-plugin/marketplace.json".text = nixPluginsMarketplace;
    "${nixPluginsPath}/feature-dev".source = "${claude-code-plugins}/plugins/feature-dev";
    "${nixPluginsPath}/ralph-wiggum".source = "${claude-code-plugins}/plugins/ralph-wiggum";
    "${nixPluginsPath}/code-review".source = "${claude-code-plugins}/plugins/code-review";
    "${nixPluginsPath}/superpowers".source = "${superpowers}";

    # Claude Code custom commands
    ".claude/commands/remember.md".source = ../../config/claude-commands/remember.md;
    ".claude/commands/recall.md".source = ../../config/claude-commands/recall.md;
    ".claude/commands/cleanup.md".source = ../../config/claude-commands/cleanup.md;
    ".claude/commands/commit.md".source = ../../config/claude-commands/commit.md;
    ".claude/commands/pr.md".source = ../../config/claude-commands/pr.md;
    ".claude/commands/docs.md".source = ../../config/claude-commands/docs.md;

    ".claude/CLAUDE.md".source = ../../config/claude/CLAUDE.md;
    ".claude/settings.json".text = builtins.replaceStrings ["@homeDir@"] [homeDir] (builtins.readFile ../../config/claude/settings.json);
    # Nix-managed empty local settings to prevent manual permission escalation
    ".claude/settings.local.json".text = builtins.toJSON {
      permissions = {
        allow = [];
        deny = [];
      };
    };
    ".claude/hooks/check-bash-command.sh" = {
      source = ../../config/claude/hooks/check-bash-command.sh;
      executable = true;
    };
    ".claude/hooks/auto-recall.sh" = {
      source = ../../config/claude/hooks/auto-recall.sh;
      executable = true;
    };
    ".claude/plugins/known_marketplaces.json".text = knownMarketplaces;

    # SSH signing key (public key from Secretive)
    ".ssh/signing_key.pub".text = userConfig.git.signingKey + "\n";
    # SSH allowed signers for git signature verification
    ".ssh/allowed_signers".text = "${userConfig.git.email} ${userConfig.git.signingKey}\n";
  };

  xdg.configFile = {
    # recursive = true so we can inject nix-paths.lua alongside the symlinked config files
    "nvim" = {
      source = ../../config/nvim;
      recursive = true;
    };
    # Generated Lua module returning configPath; required by init.lua for the lazy.nvim lockfile path
    "nvim/lua/nix-paths.lua".text = ''return "${userConfig.configPath}"'';
    "yazi/yazi.toml".source = ../../config/yazi/yazi.toml;
    "yazi/init.lua".source = ../../config/yazi/init.lua;
    # @configPath@ placeholder in keymap.toml is replaced with userConfig.configPath at build time
    "yazi/keymap.toml".text = builtins.replaceStrings ["@configPath@"] [userConfig.configPath] (builtins.readFile ../../config/yazi/keymap.toml);
    "yazi/plugins/yamb.yazi" = {
      source = yamb-yazi;
      recursive = true;
    };
    "tidal/Tidal.ghci".source = ../../config/tidal/Tidal.ghci;
    "procs/config.toml".source = ../../config/procs/config.toml;
    "wezterm/colors/earthtone-light.toml".source = "${earthtone-nvim}/extras/wezterm_light.toml";
    "wezterm/colors/earthtone-dark.toml".source = "${earthtone-nvim}/extras/wezterm_dark.toml";
  };
}
