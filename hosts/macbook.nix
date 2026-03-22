{config, ...}: {
  imports = [./common.nix];
  custom = {
    hostname = "burned-apple";
    system = "aarch64-darwin";
    configPath = "/Users/${config.custom.user}/.config/nix-darwin";
    sshAgent = "secretive";
    utmHostIp = "192.168.64.11";
  };
}
