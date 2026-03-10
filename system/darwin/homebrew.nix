_: {
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

    casks = [
      "supercollider"
      "spotify"
      "blackhole-2ch"
      "blackhole-16ch"
      "element"
      "claude"
      "brave-browser"
      "wezterm@nightly"
      "karabiner-elements"
      "tor-browser"
      "stolendata-mpv"
      "orbstack"
      "qbittorrent"
      "secretive"
      "signal"
      "cardinal"
      "keycastr"
      "zoom"
      "monitorcontrol"
      "proton-drive"
      "protonvpn"
      "gimp"
      "syncthing-app"
      "utm"
    ];
  };
}
