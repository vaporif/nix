{config, ...}: {
  imports = [./common.nix];
  custom = {
    hostname = "work-nixos";
    system = "aarch64-linux";
    configPath = "${config.custom.homeDir}/.config/nix";
    sshAgent = "";
    stateVersion = "26.05";
    # No qdrant on the work Mac, so disable the ferrex memory stack here.
    qdrant.enable = false;
  };
}
