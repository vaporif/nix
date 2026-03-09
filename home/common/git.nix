{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.custom;
  homeDir = config.home.homeDirectory;
  hasSigningKey = cfg.git.signingKey != "";
in {
  programs = {
    gh = {
      enable = true;
      extensions = [pkgs.gh-dash pkgs.gh-f];
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

    git = {
      enable = true;
      ignores = [".direnv" ".serena" ".claude" "CLAUDE.md" ".serena.bak" ".claude.bak" ".envrc.bak" ".parry-guard.redb" "CLAUDE.md.bak"];
      settings = {
        user = {
          inherit (cfg.git) name email;
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
        url."git@github.com:".insteadOf = "https://github.com/";
        interactive.diffFilter = "delta --color-only";
        delta = {
          navigate = true;
          syntax-theme = "gruvbox-light";
          line-numbers = true;
        };
      };
      signing = lib.mkIf hasSigningKey {
        key = "${homeDir}/.ssh/signing_key.pub";
        signByDefault = true;
        format = "ssh";
      };
      settings.gpg.ssh.allowedSignersFile = lib.mkIf hasSigningKey "${homeDir}/.ssh/allowed_signers";
      maintenance.enable = true;
    };
  };

  home.file = lib.mkIf hasSigningKey {
    ".ssh/signing_key.pub".text = cfg.git.signingKey + "\n";
    ".ssh/allowed_signers".text = "${cfg.git.email} ${cfg.git.signingKey}\n";
  };
}
