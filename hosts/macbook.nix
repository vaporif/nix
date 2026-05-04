{config, ...}: {
  imports = [./common.nix];
  custom = {
    hostname = "burnedapple";
    system = "aarch64-darwin";
    configPath = "${config.custom.homeDir}/.config/nix-darwin";
    sshAgent = "secretive";
    utmHostIp = "192.168.64.11";
  };
}
