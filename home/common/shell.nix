{
  pkgs,
  config,
  lib,
  ...
}: {
  programs = {
    ripgrep.enable = true;
    fd.enable = true;
    bat.enable = true;

    tealdeer = {
      enable = true;
      settings.updates.auto_update = true;
    };

    nix-index = {
      enable = true;
      enableZshIntegration = true;
    };

    jq.enable = true;

    yazi = {
      enable = true;
      enableZshIntegration = true;
      shellWrapperName = "y";
    };

    eza = {
      enable = true;
      enableZshIntegration = true;
    };

    zoxide = {
      enable = true;
      enableZshIntegration = true;
    };

    carapace = {
      enable = true;
      enableZshIntegration = true;
    };

    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
      config.global.hide_env_diff = true;
    };

    atuin = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        search_mode = "fuzzy";
        filter_mode = "host";
        style = "compact";
        show_preview = true;
        max_preview_height = 4;
        enter_accept = true;
      };
    };

    fzf = {
      enable = true;
      enableZshIntegration = true;
      defaultCommand = "fd --type f --hidden --follow --exclude .git";
      fileWidgetCommand = "fd --type f --hidden --follow --exclude .git";
      historyWidgetOptions = [
        "--no-sort"
        "--tiebreak=index"
      ];
    };

    starship = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        format = ''
          $directory$git_branch$git_state$git_status$cmd_duration$line_break$character
        '';

        directory = {
          format = "[$path]($style)[$read_only]($read_only_style) ";
          style = "bold blue";
          truncation_length = 3;
          truncate_to_repo = true;
          read_only = " 🔒";
          read_only_style = "red";
        };

        character = {
          success_symbol = "[❯](bold green)";
          error_symbol = "[❯](bold red)";
          vimcmd_symbol = "[❮](bold cyan)";
        };

        git_branch = {
          format = "[ $branch]($style)";
          style = "bold cyan";
        };

        git_status = {
          format = "[$all_status$ahead_behind]($style)";
          conflicted = "⚔️";
          ahead = "⇡$count";
          behind = "⇣$count";
          diverged = "⇕⇡$ahead_count⇣$behind_count";
          untracked = "🆕$count";
          stashed = "📦$count";
          modified = "📝$count";
          staged = "✅$count";
          renamed = "🔄$count";
          deleted = "🗑️$count";
          style = "bold yellow";
        };

        git_state = {
          format = ''\([$state( $progress_current/$progress_total)]($style)\) '';
          style = "bold yellow";
        };

        cmd_duration = {
          format = "[⏱️ $duration]($style) ";
          style = "bold yellow";
          min_time = 2000;
        };
      };
    };

    zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion = {
        enable = true;
        highlight = "fg=#939f91,bold";
      };
      syntaxHighlighting.enable = true;
      history = {
        size = 50000;
        save = 50000;
        ignoreDups = true;
        ignoreSpace = true;
        share = true;
        extended = true;
        expireDuplicatesFirst = true;
      };
      shellAliases =
        {
          t = "y";
          g = "lazygit";
          ls = "eza -a";
          e = "nvim";
          x = "exit";
          mcp-scan = "${lib.getExe pkgs.uv} tool run mcp-scan@latest";
          init-solana = "nix flake init -t github:vaporif/nix-devshells#solana";
          init-rust = "nix flake init -t github:vaporif/nix-devshells#rust";
        }
        // lib.optionalAttrs config.custom.claude.enable (let
          claudeSandboxed = lib.getExe config.custom.sandboxedPackages.claude;
        in {
          a = "${claudeSandboxed} --dangerously-skip-permissions --model opus";
          ar = "${claudeSandboxed} --dangerously-skip-permissions --resume --model opus";
        })
        // lib.optionalAttrs config.custom.codex.enable (let
          codexSandboxed = lib.getExe config.custom.sandboxedPackages.codex;
        in {
          o = "${codexSandboxed} --dangerously-bypass-approvals-and-sandbox";
          "or" = "${codexSandboxed} resume --dangerously-bypass-approvals-and-sandbox";
          ox = "${codexSandboxed} exec";
        });
      initContent =
        ''
          ulimit -Sn 4096
          ulimit -Sl unlimited

          # Only set sensitive vars outside agent sandboxes
          if [[ -z "''${CLAUDE_SANDBOX:-}" && -z "''${CODEX_SANDBOX:-}" ]]; then
            export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/key.txt"
          fi

          bindkey '^F' fzf-file-widget
          bindkey -r '^T'
        ''
        + lib.optionalString config.custom.gitlab.enable ''

          if [[ -z "''${CLAUDE_SANDBOX:-}" && -z "''${CODEX_SANDBOX:-}" && -r /run/secrets/gitlab-token && -r /run/secrets/gitlab-api-url ]]; then
            export GITLAB_TOKEN="$(cat /run/secrets/gitlab-token)"
            GITLAB_HOST="$(cat /run/secrets/gitlab-api-url)"
            export GITLAB_HOST="''${GITLAB_HOST%/api/v4}"
          fi
        ''
        + lib.optionalString config.custom.tmux.autoAttach ''

          # Persistent session: on an interactive SSH login, replace the shell
          # with a tmux session (attach if it exists, else create). Keeps the
          # shell and running programs alive across disconnects and terminal close.
          if [[ -n "''${SSH_TTY:-}" && -z "''${TMUX:-}" ]] && command -v tmux >/dev/null; then
            exec tmux new-session -A -s main
          fi
        '';
    };
  };
}
