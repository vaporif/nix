# Machine-specific hardware config (UUIDs, kernel modules, filesystems).
# Forkers: regenerate with `nixos-generate-config` and replace this file.
{...}: {
  boot = {
    initrd = {
      availableKernelModules = ["xhci_pci" "virtio_pci" "virtio_blk" "virtio_net" "virtio_gpu" "usbhid"];
      kernelModules = [];
    };
    kernelModules = [];
    extraModulePackages = [];
    kernelParams = ["console=hvc0"];
  };

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/ffa3ad57-769d-48f0-8a11-f7d8d4b83d1e";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/CA07-A248";
    fsType = "vfat";
    options = ["fmask=0022" "dmask=0022"];
  };

  swapDevices = [];
}
