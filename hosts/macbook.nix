let
  common = import ./common.nix;
in
  common
  // {
    hostname = "MacBook-Pro";
    system = "aarch64-darwin";
    configPath = "/Users/vaporif/.config/nix-darwin";
    sshAgent = "secretive";
    utmHostIp = "192.168.64.6";
  }
