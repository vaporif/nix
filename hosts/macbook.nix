{config, ...}: {
  imports = [./common.nix];
  custom = {
    hostname = "MacBook-Pro";
    system = "aarch64-darwin";
    configPath = "/Users/${config.custom.user}/.config/nix-darwin";
    sshAgent = "secretive";
    utmHostIp = "192.168.64.6";
  };
}
