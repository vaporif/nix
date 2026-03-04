_: {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    extraOptionOverrides = {
      StrictHostKeyChecking = "ask";
      HashKnownHosts = "yes";
      KexAlgorithms = "curve25519-sha256,curve25519-sha256@libssh.org";
      HostKeyAlgorithms = "ssh-ed25519,sk-ssh-ed25519@openssh.com";
      Ciphers = "aes256-gcm@openssh.com,chacha20-poly1305@openssh.com";
      MACs = "hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com";
    };
    matchBlocks."*" = {
      addKeysToAgent = "yes";
      serverAliveInterval = 60;
      serverAliveCountMax = 3;
    };
  };
}
