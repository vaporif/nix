_: {
  services = {
    skhd = {
      enable = true;
      skhdConfig = ''
        # App shortcuts (hyper = caps lock via karabiner)
        # Left hand
        # Direct path + --env avoid Hyper's held modifiers triggering mac-app-util's dialog and Firefox's Troubleshoot Mode.
        hyper - r : /usr/bin/open --env MOZ_DISABLE_SAFE_MODE_KEY=1 "$HOME/Applications/Home Manager Apps/LibreWolf.app" # lib[r]ewolf
        hyper - t : open -a "wezterm"               # [t]erminal
        hyper - c : open -a "Claude"                # [c]laude
        hyper - s : open -a "Slack"                 # [s]lack
        hyper - b : open -a "Brave Browser"         # [b]rave
        hyper - d : open -a "Discord"               # [d]iscord
        # Right hand
        hyper - w : open -a "WhatsApp"              # [w]hatsapp
        hyper - m : open -a "Ableton Live 12 Suite" # [m]usic
        hyper - l : open -a "Signal"                # signa[l]
        hyper - p : open -a "Spotify"               # s[p]otify
      '';
    };
  };
}
