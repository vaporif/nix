{...}: {
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
    # Privacy-focused DNS resolvers (Quad9 + Cloudflare)
    dns = ["9.9.9.9" "1.1.1.1"];
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
      # Enforce automatic security updates
      "com.apple.SoftwareUpdate" = {
        AutomaticCheckEnabled = true;
        AutomaticDownload = true;
        CriticalUpdateInstall = true;
        ConfigDataInstall = true;
      };
    };

    # Stricter umask - new files only readable by owner
    activationScripts.umask.text = ''
      launchctl config user umask 077
    '';

    # Disable Handoff (activity broadcasting to nearby Apple devices)
    # Uses activation script because these are -currentHost defaults (ByHost domain)
    activationScripts.disableHandoff.text = ''
      defaults -currentHost write com.apple.coreservices.useractivityd ActivityAdvertisingAllowed -bool false
      defaults -currentHost write com.apple.coreservices.useractivityd ActivityReceivingAllowed -bool false
    '';
  };
}
