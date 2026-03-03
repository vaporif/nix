# Shared config inherited by all hosts.
# Per-host files (macbook.nix, nixos.nix) import this and add:
#   hostname  (string)  - machine name, used as flake output key
#   system    (string)  - "aarch64-darwin" | "aarch64-linux" | "x86_64-darwin" | "x86_64-linux"
#   configPath (string) - absolute path to this repo on the host
#   sshAgent  (string)  - "secretive" for macOS Secretive.app, "" otherwise
# Optional per-host fields:
#   utmHostIp (string)  - IP of UTM VM for SSH config (macOS only)
{
  user = "vaporif";

  git = {
    name = "Dmytro Onypko";
    email = "vaporif@proton.me";
    signingKey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBP7sf4L6CNhRgdRKmXH2H7xxWTEWMTCS/oOkOwZIIIrpoVeXj01gVp6G4Al0+MdekYO9QbVGX4WMX8+hMpUXs/M= github@secretive.MacBook-Pro.local";
  };

  cachix = {
    name = "vaporif";
    publicKey = "vaporif.cachix.org-1:y/fKd8ILM10UJCdXFFYn/n8+AqXnRLzwHjX+BikcUf8=";
  };

  timezone = "Europe/Lisbon";
}
