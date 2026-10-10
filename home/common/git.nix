{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.custom;
  homeDir = config.home.homeDirectory;
  hasSigningKey = cfg.git.signingKey != "";
  hasGitlabSecrets =
    cfg.gitlab.enable
    && cfg.secrets.gitlab-token != null
    && cfg.secrets.gitlab-api-url != null;
  glabAliases = pkgs.writeText "glab-aliases.yml" ''
    ci: pipeline ci
    co: mr checkout
    ml: mr list
    mv: mr view --web
    md: mr diff
    mm: mr merge
    ma: mr approve
    mn: mr note
    ms: mr list --reviewer=@me
  '';
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
        git.diffRenderers = [
          {
            command = "delta --paging=never";
            colorArg = "always";
          }
        ];
      };
    };

    git = {
      enable = true;
      ignores = [".direnv" ".claude" "CLAUDE.md" ".claude.bak" ".envrc.bak" ".parry-guard.redb" "CLAUDE.md.bak" "docs/superpowers/"];
      settings = {
        user = {
          inherit (cfg.git) name email;
        };
        core = {
          editor = "nvim";
          pager = "delta";
        };
        alias = {
          c = "checkout";
          p = "push";
          pl = "pull";
          d = "diff";
          ds = "diff --staged";
          # Structural diffs on demand; diff.external stays unset so tools that
          # parse `git diff` (agents, patch generation) get a real patch.
          dft = "-c diff.external=difft diff";
          dfts = "-c diff.external=difft diff --staged";
          dfl = "-c diff.external=difft log -p --ext-diff";
          undo = "reset --soft HEAD~1";
          upd = "!git add -A && git commit -m upd";
          discard = "reset HEAD --hard";
          fp = "fetch --all --prune";
          bclone = "!git-bare-clone";
          wb = "!git-worktree-new";
          wr = "!git-worktree-remove";
          wl = "worktree list";
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
        diff.algorithm = "histogram";
        feature.experimental = true;
        help.autocorrect = "prompt";
        branch.sort = "committerdate";
        branch.autoSetupMerge = "simple";
        url."git@github.com:".insteadOf = "https://github.com/";
        url."git@codeberg.org:".insteadOf = "https://codeberg.org/";
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

  home.activation = {
    glabAliases = lib.hm.dag.entryAfter ["writeBoundary"] ''
      $DRY_RUN_CMD install -Dm600 ${glabAliases} "$HOME/.config/glab-cli/aliases.yml"
    '';

    # Rendered from the sops secrets at switch time so `glab auth status` and
    # shells that never source zshrc see the token. The api-url secret carries
    # /api/v4, which glab's host key must not have.
    glabConfig = lib.mkIf hasGitlabSecrets (lib.hm.dag.entryAfter ["writeBoundary"] ''
      if [[ -r ${cfg.secrets.gitlab-token} && -r ${cfg.secrets.gitlab-api-url} ]]; then
        glabHost="$(<${cfg.secrets.gitlab-api-url})"
        glabHost="''${glabHost%/api/v4}"
        glabHost="''${glabHost#https://}"
        if [[ -z "''${DRY_RUN:-}" ]]; then
          mkdir -p "$HOME/.config/glab-cli"
          (
            umask 077
            cat > "$HOME/.config/glab-cli/config.yml" <<EOF
      git_protocol: ssh
      check_update: false
      host: $glabHost
      hosts:
        $glabHost:
          token: $(<${cfg.secrets.gitlab-token})
          api_protocol: https
          git_protocol: ssh
      EOF
          )
          chmod 600 "$HOME/.config/glab-cli/config.yml"
        fi
      fi
    '');
  };

  home.file = lib.mkIf hasSigningKey {
    ".ssh/signing_key.pub".text = cfg.git.signingKey + "\n";
    ".ssh/allowed_signers".text = "${cfg.git.email} ${cfg.git.signingKey}\n";
  };
}
