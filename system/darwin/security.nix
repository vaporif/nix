{...}: {
  imports = [
    ../../modules/sops.nix
  ];

  networking.applicationFirewall = {
    enable = true;
    enableStealthMode = true;
    blockAllIncoming = false;
    allowSigned = true;
    allowSignedApp = false;
  };

  security = {
    pam.services.sudo_local.touchIdAuth = true;
    sudo.extraConfig = ''
      Defaults timestamp_timeout=1
    '';
  };

  # Stricter umask - new files only readable by owner
  system.activationScripts.umask.text = ''
    launchctl config user umask 077
  '';
}
