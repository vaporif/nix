{config, ...}: {
  imports = [./common.nix];
  custom = {
    hostname = "personal-nixos";
    system = "aarch64-linux";
    configPath = "${config.custom.homeDir}/.config/nix";
    sshAgent = "";
  };
}
