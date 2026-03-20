{lib, ...}: {
  imports = [
    ../../modules/sops.nix
  ];

  networking = {
    applicationFirewall = {
      enable = true;
      enableStealthMode = true;
      blockAllIncoming = false;
      allowSigned = true;
      allowSignedApp = false;
    };
    # Privacy-focused DNS resolvers (Quad9)
    dns = ["9.9.9.9" "149.112.112.112"];
    # List active interfaces: networksetup -listallnetworkservices
    knownNetworkServices = ["Wi-Fi" "Thunderbolt Bridge"];
  };

  security = {
    pam.services.sudo_local.touchIdAuth = true;
    sudo.extraConfig = ''
      Defaults timestamp_timeout=1
    '';
  };

  system = {
    defaults.CustomSystemPreferences = {
      # Disable captive portal detection (prevents phoning captive.apple.com on every network change)
      "com.apple.captive.control".Active = false;
      # Prevent FileVault from being disabled
      "com.apple.MCX".dontAllowFDEDisable = true;
      # Enforce automatic security updates
      "com.apple.SoftwareUpdate" = {
        AutomaticCheckEnabled = true;
        AutomaticDownload = true;
        CriticalUpdateInstall = true;
        ConfigDataInstall = true;
      };
    };

    activationScripts = {
      # Stricter umask - new files only readable by owner
      umask.text = ''
        launchctl config user umask 077
      '';

      # Restrict qdrant ports to localhost + UTM subnet only
      qdrantFirewall.text = let
        anchorRules = ''
          pass in quick proto tcp from 127.0.0.0/8 to any port { 6333, 6334 }
          pass in quick proto tcp from 192.168.64.0/24 to any port { 6333, 6334 }
          block in quick proto tcp from any to any port { 6333, 6334 }
        '';
      in ''
        mkdir -p /etc/pf.anchors
        cat > /etc/pf.anchors/qdrant <<'RULES'
        ${anchorRules}
        RULES

        if ! grep -q 'anchor "qdrant"' /etc/pf.conf 2>/dev/null; then
          printf '%s\n' 'anchor "qdrant"' 'load anchor "qdrant" from "/etc/pf.anchors/qdrant"' >> /etc/pf.conf
        fi

        pfctl -f /etc/pf.conf 2>/dev/null || true
        pfctl -e 2>/dev/null || true
      '';

      # Disable Handoff (activity broadcasting to nearby Apple devices)
      # Uses activation script because these are -currentHost defaults (ByHost domain)
      disableHandoff.text = ''
        defaults -currentHost write com.apple.coreservices.useractivityd ActivityAdvertisingAllowed -bool false
        defaults -currentHost write com.apple.coreservices.useractivityd ActivityReceivingAllowed -bool false
      '';
    };
  };
}
