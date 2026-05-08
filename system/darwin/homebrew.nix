{
  config,
  lib,
  ...
}: let
  hmCfg = config.home-manager.users.${config.custom.user}.custom;
in {
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap";
    };

    taps = [
      "homebrew/bundle"
      "homebrew/services"
    ];

    brews = [
      "molten-vk"
    ];

    casks =
      [
        "supercollider"
        "spotify"
        "blackhole-2ch"
        "blackhole-16ch"
        "brave-browser"
        "karabiner-elements"
        "tor-browser"
        "orbstack"
        "secretive"
        "cardinal"
        "zoom"
        "proton-drive"
        "protonvpn"
        "gimp"
        "syncthing-app"
        "utm"
      ]
      ++ lib.optionals hmCfg.claude.enable [
        "claude"
      ];
  };
}
