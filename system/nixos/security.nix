{...}: {
  imports = [
    ../../modules/sops.nix
  ];

  # Privacy-focused DNS resolvers (Quad9)
  networking = {
    nameservers = ["9.9.9.9" "149.112.112.112"];
    firewall = {
      enable = true;
      allowedTCPPorts = [22];
      allowedUDPPorts = [];
      logRefusedConnections = true;
    };
  };

  security = {
    sudo.extraConfig = ''
      Defaults timestamp_timeout=1
      Defaults use_pty
    '';
    loginDefs.settings.UMASK = "077";
    audit = {
      enable = true;
      rules = [
        "-a exit,always -F arch=b64 -S execve -k exec"
        "-w /etc/passwd -p wa -k passwd_changes"
        "-w /etc/shadow -p wa -k shadow_changes"
        "-w /etc/sudoers -p wa -k sudoers_changes"
      ];
    };
  };

  # Tmpfs for /tmp (cleared on reboot, prevents sensitive data persistence)
  boot.tmp.useTmpfs = true;

  boot.kernel.sysctl = {
    # Existing
    "net.ipv4.conf.all.forwarding" = false;
    "net.ipv4.conf.all.accept_redirects" = false;
    "net.ipv6.conf.all.accept_redirects" = false;
    "net.ipv4.tcp_syncookies" = true;
    "kernel.unprivileged_bpf_disabled" = 1;

    # Kernel hardening
    "kernel.kptr_restrict" = 2;
    "kernel.dmesg_restrict" = 1;
    "kernel.sysrq" = 0;
    "kernel.yama.ptrace_scope" = 2;
    "kernel.core_uses_pid" = 1;
    "fs.suid_dumpable" = 0;

    # Network hardening
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
    "net.ipv4.icmp_ignore_bogus_error_responses" = 1;
  };

  # SSH brute-force protection
  services.fail2ban = {
    enable = true;
    maxretry = 3;
    bantime = "24h";
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
