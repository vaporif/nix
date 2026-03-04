{config, ...}: {
  imports = [./common.nix];
  custom = {
    hostname = "nixos";
    system = "aarch64-linux";
    configPath = "/home/${config.custom.user}/.config/nix";
    sshAgent = "";
  };
}
