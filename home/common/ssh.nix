{
  config,
  lib,
  ...
}: let
  cfg = config.custom;
in {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    # Work hosts sit in sops so the bastion IP and internal layout never reach
    # the public repo; a missing secret just skips the Include.
    includes = lib.optionals (cfg.workSsh.enable && cfg.secrets.ssh-work-config != null) [
      cfg.secrets.ssh-work-config
    ];
    extraOptionOverrides = {
      StrictHostKeyChecking = "ask";
      HashKnownHosts = "yes";
      KexAlgorithms = "curve25519-sha256,curve25519-sha256@libssh.org";
      HostKeyAlgorithms = "ssh-ed25519,sk-ssh-ed25519@openssh.com";
      Ciphers = "aes256-gcm@openssh.com,chacha20-poly1305@openssh.com";
      MACs = "hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com";
    };
    settings = {
      "*" = {
        AddKeysToAgent = "yes";
        ServerAliveInterval = 60;
        ServerAliveCountMax = 3;
      };
      "codeberg.org" = {
        User = "git";
        HostName = "codeberg.org";
      };
    };
  };
}
