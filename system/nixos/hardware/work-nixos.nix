{lib, ...}: {
  imports = [];

  boot = {
    initrd = {
      availableKernelModules = ["nvme" "ahci" "virtio_pci" "xhci_pci" "usbhid" "usb_storage" "sd_mod" "sr_mod"];
      kernelModules = [];
    };
    kernelModules = [];
    extraModulePackages = [];
  };

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/63132c8d-b619-42c7-ba7d-c1a4cd8e8581";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/1F09-E40E";
    fsType = "vfat";
    options = ["fmask=0022" "dmask=0022"];
  };

  # Overrides the 50% shared default; this host also has a disk swapfile.
  zramSwap.memoryPercent = lib.mkForce 25;

  swapDevices = [
    {
      device = "/swapfile";
      size = 8192; # MiB
    }
  ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
