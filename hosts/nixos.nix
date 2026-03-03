let
  common = import ./common.nix;
in
  common
  // {
    hostname = "nixos";
    system = "aarch64-linux";
    configPath = "/home/vaporif/.config/nix";
    sshAgent = "";
  }
