_: {
  services = {
    skhd = {
      enable = true;
      skhdConfig = ''
        # App shortcuts (hyper = caps lock via karabiner)
        # Left hand
        # Direct paths bypass LaunchServices name lookup, which resolves to mac-app-util's
        # AppleScript trampoline — Hyper's held modifiers make that applet pop a run/quit dialog.
        # --env additionally suppresses Firefox's Troubleshoot Mode prompt.
        hyper - r : /usr/bin/open --env MOZ_DISABLE_SAFE_MODE_KEY=1 "$HOME/Applications/Home Manager Apps/LibreWolf.app" # lib[r]ewolf
        hyper - t : /usr/bin/open "$HOME/Applications/Home Manager Apps/WezTerm.app" # [t]erminal
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
