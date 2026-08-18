{
  config,
  lib,
  ...
}: let
  # Attach to a single long-lived session, creating it on first launch. Every
  # Ghostty surface becomes a client of that session, so multiplexing stays
  # entirely in tmux (which already owns the prefix, splits and Alt-N bindings).
  tmuxAttach = "${lib.getExe config.programs.tmux.package} new-session -A -s main";
in {
  programs.ghostty = {
    enable = true;

    # nixpkgs marks ghostty linux-only — the macOS app is an Xcode/Swift build
    # the sandbox can't produce. The brew cask in system/darwin/homebrew.nix
    # installs the app; home-manager only owns the config here.
    package = null;

    # Ghostty auto-injects shell integration only into shells it spawns
    # directly, which excludes every shell under tmux. Sourcing it from .zshrc
    # keeps cwd inheritance, prompt marking and the sudo terminfo wrapper
    # working inside tmux panes.
    enableZshIntegration = true;

    settings = {
      command = tmuxAttach;

      # stylix emits one font-family per configured font, and modules/theme.nix
      # deliberately sets an empty emoji font — which reaches Ghostty as a bare
      # `font-family =` it rejects. Keep just the monospace family.
      font-family = lib.mkForce [config.stylix.fonts.monospace.name];

      # tmux binds Alt-1..Alt-9 for window selection; without this Option
      # composes Unicode instead of sending Alt on non-US layouts.
      macos-option-as-alt = true;

      # ssh-terminfo installs the xterm-ghostty entry on remote hosts that lack
      # it; ssh-env keeps TERM sane for the ones that still don't. The first
      # three are Ghostty's defaults, restated because naming any feature
      # replaces the whole set.
      shell-integration-features = "cursor,sudo,title,ssh-env,ssh-terminfo";

      # Carried over from the wezterm config: same padding, no cursor blink,
      # same scrollback depth as tmux's history-limit.
      window-padding-x = 15;
      window-padding-y = "10,5";
      cursor-style-blink = false;
      scrollback-limit-lines = 50000;

      # wezterm bound right-click to paste and copied on left-click release;
      # copy-on-select is already Ghostty's macOS default.
      right-click-action = "paste";
      mouse-hide-while-typing = true;

      keybind = [
        "super+y=copy_to_clipboard"
        "super+p=paste_from_clipboard"
        "alt+enter=toggle_fullscreen"
      ];
    };
  };
}
