{
  pkgs,
  config,
  lib,
  ...
}: let
  claudeSandboxed = lib.getExe config.custom.sandboxedPackages.claude;
in {
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
      shellAliases = {
        t = "y";
        g = "lazygit";
        a = "${claudeSandboxed} --dangerously-skip-permissions";
        ac = claudeSandboxed;
        ap = "${claudeSandboxed} --print --dangerously-skip-permissions";
        ar = "${claudeSandboxed} --resume --dangerously-skip-permissions";
        au = "claude --dangerously-skip-permissions";
        auc = "claude";
        aup = "claude --print --dangerously-skip-permissions";
        aur = "claude --resume --dangerously-skip-permissions";
        ls = "eza -a";
        cat = "bat";
        e = "nvim";
        x = "exit";
        mcp-scan = "${pkgs.uv}/bin/uv tool run mcp-scan@latest";
        init-solana = "nix flake init -t github:vaporif/nix-devshells#solana";
        init-rust = "nix flake init -t github:vaporif/nix-devshells#rust";
      };
      initContent = ''
        ulimit -Sn 4096
        ulimit -Sl unlimited

        # Only set sensitive vars outside Claude sandbox
        if [[ -z "''${CLAUDE_SANDBOX:-}" ]]; then
          export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/key.txt"
        fi

        bindkey '^F' fzf-file-widget
        bindkey -r '^T'
      '';
    };
  };
}
