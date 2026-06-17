# PLACEHOLDER — regenerate inside the VMware Fusion VM on the work Mac.
#
# This file holds machine-specific data (disk UUIDs, kernel modules) that
# differs per VM and CANNOT be copied from personal-nixos.nix. To produce
# the real file, boot the work-Mac NixOS guest and run:
#
#   sudo nixos-generate-config --show-hardware-config > hardware.nix
#
# then replace the body below with its contents (keep this path/filename).
# The values here are a best-guess scaffold so the flake still evaluates;
# they will not boot a real machine until regenerated.
{lib, ...}: {
  imports = [];

  boot = {
    initrd = {
      availableKernelModules = ["virtio_pci" "xhci_pci" "usbhid" "usb_storage" "sd_mod" "sr_mod"];
      kernelModules = [];
    };
    kernelModules = [];
    extraModulePackages = [];
  };

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/63132c8d-b619-42c7-ba7d-c1a4cd8e8581";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/1F09-E40E";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };

  swapDevices = [];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
