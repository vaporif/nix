{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.custom;
  c = config.lib.stylix.colors.withHashtag;

  # Claude session state in the tmux status bar. claude/tab-state.sh can only
  # reach tmux in-band, so the state arrives as a glyph prefixed to the window
  # name (⠿ working, ? waiting, ✓ done, · started); these formats match it,
  # color it, and animate the working one.
  #
  # tmux has no clock in formats, but status formats pass through strftime
  # first: %S becomes the second and %% a literal %, so the tick below is
  # "second mod frame count" by the time the format engine sees it.
  spinFrames = ["⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏"];
  spinTick = "#{e|%%:%S,${toString (builtins.length spinFrames)}}";
  spinner =
    lib.foldr
    (i: rest: "#{?#{==:${spinTick},${toString i}},${builtins.elemAt spinFrames i},${rest}}")
    (lib.last spinFrames)
    (lib.range 0 (builtins.length spinFrames - 2));
  isState = glyph: "#{m:${glyph} *,#{window_name}}";
  claudeGlyph = lib.concatStrings [
    "#{?${isState "⠿"},#[fg=${c.base0B}]${spinner} ,"
    "#{?${isState "[?]"},#[fg=${c.base08}#,bold]? ,"
    "#{?${isState "✓"},#[fg=${c.base0C}]✓ ,"
    "#{?${isState "·"},#[fg=${c.base03}]· ,"
    "}}}}"
  ];
  windowName = "#{s/^(⠿|[?]|✓|·) //:window_name}";
  countState = glyph: "#{n:#{W:#{?${isState glyph},x,}}}";
  claudeSummary = lib.concatStrings [
    "#{?#{!=:${countState "[?]"},0},#[fg=${c.base08}#,bold]${countState "[?]"} waiting#[nobold]  ,}"
    "#{?#{!=:${countState "⠿"},0},#[fg=${c.base0B}]${countState "⠿"} working  ,}"
  ];
in {
  imports = [
    ./llm
    ../../claude/home.nix
    ./codex
    ./git.nix
    ./ssh.nix
    ./mcp.nix
    ./lspmux.nix
    ./xdg.nix
    ./packages.nix
    ./shell.nix
    ./neovim.nix
    ./sandboxed.nix
  ];

  custom.lspmux.enable = true;

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
      COLORTERM = "truecolor";
      ENABLE_LSP_TOOL = "1";
      DFT_GRAPH_LIMIT = "500000";
      DFT_BYTE_LIMIT = "1000000";
      # Silence Boehm GC's "repeated allocation of very large block" noise
      # during nix evaluation; it is a heuristic, not a leak.
      GC_LARGE_ALLOC_WARN_INTERVAL = "1000";
      # Same path on both platforms so the host and the sandboxes share one
      # cache; projects opt in via RUSTC_WRAPPER in their own flakes.
      SCCACHE_DIR = "$HOME/.cache/sccache";
      SCCACHE_CACHE_SIZE = "256G";
    };
    file = {
      ".envrc".text = ''
        use flake "github:vaporif/nix-devshells/${inputs.nix-devshells.rev}"
      '';
    };
  };

  # own the tmux layout via extraConfig; still uses stylix's palette via `c`
  stylix.targets.tmux.enable = false;

  # Rofi is unused, and stylix's target still writes the renamed
  # `programs.rofi.font`.
  stylix.targets.rofi.enable = false;

  programs = {
    home-manager.enable = true;

    btop = {
      enable = true;
      settings.update_ms = 100;
    };

    tmux = {
      enable = true;
      prefix = "C-a";
      baseIndex = 1;
      terminal = "tmux-256color";
      # resurrect saves/restores sessions; continuum auto-saves and restores
      # on server start. continuum must load last, so keep it last in the list.
      plugins = with pkgs.tmuxPlugins; [
        {
          plugin = resurrect;
          extraConfig = ''
            set -g @resurrect-strategy-nvim 'session'
            set -g @resurrect-capture-pane-contents 'on'
          '';
        }
        {
          plugin = extrakto;
          extraConfig = ''
            set -g @extrakto_key 'tab'
            set -g @extrakto_clip_tool 'tmux'
          '';
        }
        {
          plugin = continuum;
          extraConfig = ''
            set -g @continuum-restore 'on'
            set -g @continuum-save-interval '5'
          '';
        }
      ];
      extraConfig = ''
        set -g prefix2 C-b
        set -g pane-base-index 1
        set -g renumber-windows on
        set -sg escape-time 0
        set -g mouse on
        set -g focus-events on
        # Pass modified keys (e.g. C-S-t) through as CSI-u to apps that ask for them
        set -s extended-keys on
        set -as terminal-features 'xterm-ghostty:extkeys'
        set -g history-limit 50000
        set -g set-clipboard on
        set -g allow-passthrough on
        set -g set-titles on
        set -g set-titles-string "#T"
        # Lets a program rename its window in-band (ESC k). Claude's tab-state
        # hook needs this: it runs in the VM over ssh, where the tmux CLI is
        # unreachable, so the state glyph can only arrive as an escape.
        set -g allow-rename on
        # Size windows to the clients viewing them, not the smallest client
        # attached; otherwise a second client makes full-screen TUIs tear.
        setw -g aggressive-resize on
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
        set -ga terminal-features ",xterm-ghostty:usstyle:clipboard:hyperlinks:sync:osc7"
        set -ga update-environment " GHOSTTY_RESOURCES_DIR GHOSTTY_BIN_DIR"

        # ── ultra-minimal status bar (colors from stylix palette) ──
        set -g status-position bottom
        # 1s drives the Claude spinner; tmux can't redraw the bar any faster
        set -g status-interval 1
        set -g status-justify left
        set -g status-style "bg=default,fg=${c.base04}"

        # small left gap, no session block
        set -g status-left " "
        set -g status-left-length 1

        set -g status-right "${claudeSummary}#[fg=${c.base03}]%H:%M "
        set -g status-right-length 40

        # tabs: dim inactive, bold accent active, no backgrounds
        set -g window-status-separator "  "
        set -g window-status-format "#[fg=${c.base03}]#I ${claudeGlyph}#[fg=${c.base04}#,nobold]${windowName}"
        set -g window-status-current-format "#[fg=${c.base0C},bold]#I ${claudeGlyph}#[fg=${c.base0C},bold]${windowName}"
        set -g window-status-activity-style "fg=${c.base09}"
        set -g window-status-bell-style "fg=${c.base08},bold"

        # panes / messages / copy-mode
        set -g pane-border-style "fg=${c.base02}"
        set -g pane-active-border-style "fg=${c.base0C}"
        set -g message-style "bg=${c.base00},fg=${c.base05}"
        set -g message-command-style "bg=${c.base00},fg=${c.base05}"
        set -g mode-style "bg=${c.base02},fg=${c.base05}"

        # new windows / splits inherit the current pane's path
        # c = new tab; v = stacked, h = side by side — matches wezterm
        bind c new-window -c "#{pane_current_path}"
        bind v split-window -v -c "#{pane_current_path}"
        bind h split-window -h -c "#{pane_current_path}"
        # close pane without confirmation prompt
        bind x kill-pane
        bind A display-popup -E -w 90% -h 90% -d "#{pane_current_path}" "claude agents"
        # agent swarm runs on its own socket (claude-swarm-N); attach the newest
        bind S display-popup -E -w 95% -h 90% \
          'TMUX= tmux -L "$(ls /tmp/tmux-$(id -u) | grep claude-swarm | sort -V | tail -1)" attach -t claude-swarm'

        bind m switch-client -T movewin
        bind -T movewin n swap-window -t -1 \; switch-client -T movewin
        bind -T movewin i swap-window -t +1 \; switch-client -T movewin
        bind -T movewin Escape switch-client -T root
        bind -T movewin Enter switch-client -T root

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

        # Ctrl-t: toggle a bottom drawer (mirrors the wezterm Ctrl+t split).
        # 1 pane        -> open a 70% bottom split, focused
        # 2 panes, flat -> focus the top pane and zoom it (hides the drawer)
        # 2 panes, zoom -> unzoom and focus the bottom drawer
        bind -n C-t if-shell -F '#{==:#{window_panes},1}' {
          split-window -v -l 70% -c "#{pane_current_path}"
        } {
          if-shell -F '#{window_zoomed_flag}' {
            resize-pane -Z
            select-pane -t '{bottom}'
          } {
            select-pane -t '{top}'
            resize-pane -Z
          }
        }
      '';
    };

    parry-guard =
      {
        enable = pkgs.stdenv.hostPlatform.isDarwin;
        package = inputs.parry-guard.packages.${pkgs.stdenv.hostPlatform.system}.default;
        ignoreDirs = ["${cfg.homeDir}/Repos/"];
      }
      // lib.optionalAttrs (cfg.secrets.hf-token-scan-injection != null) {
        hfTokenFile = cfg.secrets.hf-token-scan-injection;
      };
  };
}
