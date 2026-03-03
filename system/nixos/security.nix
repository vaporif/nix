{...}: {
  imports = [
    ../../modules/sops.nix
  ];

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [22];
    allowedUDPPorts = [];
    logRefusedConnections = true;
  };

  security.sudo.extraConfig = ''
    Defaults timestamp_timeout=1
  '';

  security.loginDefs.settings.UMASK = "077";

  boot.kernel.sysctl = {
    "net.ipv4.conf.all.forwarding" = false;
    "net.ipv4.conf.all.accept_redirects" = false;
    "net.ipv6.conf.all.accept_redirects" = false;
    "net.ipv4.tcp_syncookies" = true;
    "kernel.unprivileged_bpf_disabled" = 1;
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      KbdInteractiveAuthentication = false;
      X11Forwarding = false;
      MaxAuthTries = 3;
      ClientAliveInterval = 300;
      ClientAliveCountMax = 2;
    };
  };
}
