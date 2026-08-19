{
  config,
  inputs,
  lib,
  ...
}: let
  tmuxAttach = "${lib.getExe config.programs.tmux.package} new-session -A -s main";
  tmuxWindowKeys = lib.concatLists (lib.imap1 (n: name: [
    "super+physical:${name}=text:\\x1b${toString n}"
    "super+${toString n}=text:\\x1b${toString n}"
  ]) ["one" "two" "three" "four" "five" "six" "seven" "eight" "nine"]);
in {
  programs.ghostty = {
    enable = true;
    package = null;
    enableZshIntegration = true;

    settings = {
      command = tmuxAttach;
      custom-shader = "${inputs.ghostty-cursor-shaders}/cursor_warp.glsl";
      font-family = lib.mkForce [config.stylix.fonts.monospace.name];
      font-size = lib.mkForce config.stylix.fonts.sizes.terminal;
      macos-option-as-alt = true;
      shell-integration-features = "cursor,sudo,title,ssh-env,ssh-terminfo";
      window-padding-x = 10;
      window-padding-y = "2,0";
      cursor-style-blink = false;
      maximize = true;
      window-save-state = "never";
      right-click-action = "paste";
      mouse-hide-while-typing = true;

      keybind =
        [
          "super+y=copy_to_clipboard"
          "super+p=paste_from_clipboard"
          "alt+enter=toggle_fullscreen"
        ]
        ++ tmuxWindowKeys;
    };
  };
}
