{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.custom;
  c = config.lib.stylix.colors.withHashtag;
in {
  imports = [
    ./llm
    ../../claude/home.nix
    ./codex
    ./git.nix
    ./ssh.nix
    ./mcp.nix
    ./xdg.nix
    ./packages.nix
    ./shell.nix
    ./neovim.nix
    ./sandboxed.nix
  ];

  custom.lspPackages = [
    pkgs.lua-language-server
    pkgs.typescript-language-server
    pkgs.basedpyright
    pkgs.nixd
  ];

  manual = {
    manpages.enable = false;
    html.enable = false;
    json.enable = false;
  };

  home = {
    homeDirectory = cfg.homeDir;
    username = cfg.user;
    stateVersion = "24.05";
    sessionPath = [
      "$HOME/.cargo/bin"
    ];
    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      ENABLE_LSP_TOOL = "1";
      DFT_GRAPH_LIMIT = "500000";
      DFT_BYTE_LIMIT = "1000000";
    };
    file = {
      ".envrc".text = ''
        use flake "github:vaporif/nix-devshells/${inputs.nix-devshells.rev}"
      '';
    };
  };

  # own the tmux layout via extraConfig; still uses stylix's palette via `c`
  stylix.targets.tmux.enable = false;

  programs = {
    home-manager.enable = true;

    btop.enable = true;

    tmux = {
      enable = true;
      prefix = "C-a";
      baseIndex = 1;
      terminal = "tmux-256color";
      extraConfig = ''
        set -g pane-base-index 1
        set -g renumber-windows on
        set -sg escape-time 0
        set -g mouse on
        set -g focus-events on
        set -g history-limit 50000
        set -g set-clipboard on
        set -g allow-passthrough on
        setw -g monitor-activity on
        setw -g mode-keys vi
        bind -T copy-mode-vi v send -X begin-selection
        bind -T copy-mode-vi y send -X copy-selection-and-cancel
        # slow wheel scroll: 1 line per tick instead of the default burst
        bind -T copy-mode-vi WheelUpPane   send -N1 -X scroll-up
        bind -T copy-mode-vi WheelDownPane send -N1 -X scroll-down
        set -ga terminal-overrides ",*256col*:Tc"
        set -ga terminal-features ",*:RGB"
        set -ga terminal-overrides ',*:Ss=\E[%p1%d q:Se=\E[ q'

        # ── ultra-minimal status bar (colors from stylix palette) ──
        set -g status-position bottom
        set -g status-interval 5
        set -g status-justify left
        set -g status-style "bg=default,fg=${c.base04}"

        # small left gap, no session block
        set -g status-left " "
        set -g status-left-length 1

        set -g status-right "#[fg=${c.base03}]%H:%M "
        set -g status-right-length 12

        # tabs: dim inactive, bold accent active, no backgrounds
        set -g window-status-separator "  "
        set -g window-status-format "#[fg=${c.base03}]#I #[fg=${c.base04}]#W"
        set -g window-status-current-format "#[fg=${c.base0C},bold]#I #W"
        set -g window-status-activity-style "fg=${c.base09}"
        set -g window-status-bell-style "fg=${c.base08},bold"

        # panes / messages / copy-mode
        set -g pane-border-style "fg=${c.base02}"
        set -g pane-active-border-style "fg=${c.base0C}"
        set -g message-style "bg=${c.base00},fg=${c.base05}"
        set -g message-command-style "bg=${c.base00},fg=${c.base05}"
        set -g mode-style "bg=${c.base02},fg=${c.base05}"

        # new windows / splits inherit the current pane's path
        bind c new-window -c "#{pane_current_path}"
        bind '"' split-window -v -c "#{pane_current_path}"
        bind % split-window -h -c "#{pane_current_path}"

        # Alt-1..9 select window 1..9 (no prefix)
        bind -n M-1 select-window -t 1
        bind -n M-2 select-window -t 2
        bind -n M-3 select-window -t 3
        bind -n M-4 select-window -t 4
        bind -n M-5 select-window -t 5
        bind -n M-6 select-window -t 6
        bind -n M-7 select-window -t 7
        bind -n M-8 select-window -t 8
        bind -n M-9 select-window -t 9

        # Ctrl-t: toggle floating scratch terminal (one per window/tab)
        bind -n C-t if-shell -F '#{m:scratch-*,#{session_name}}' \
          'detach-client' \
          'display-popup -E -w 80% -h 80% "tmux attach -t scratch-#{s/@//:window_id} || tmux new -s scratch-#{s/@//:window_id}"'
      '';
    };

    parry-guard =
      {
        enable = pkgs.stdenv.isDarwin;
        package = inputs.parry-guard.packages.${pkgs.stdenv.hostPlatform.system}.default;
        ignoreDirs = ["${cfg.homeDir}/Repos/"];
      }
      // lib.optionalAttrs (cfg.secrets.hf-token-scan-injection != null) {
        hfTokenFile = cfg.secrets.hf-token-scan-injection;
      };
  };
}
