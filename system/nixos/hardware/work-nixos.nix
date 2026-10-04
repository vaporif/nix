{lib, ...}: {
  imports = [];

  boot = {
    initrd = {
      availableKernelModules = ["nvme" "ahci" "virtio_pci" "xhci_pci" "usbhid" "usb_storage" "sd_mod" "sr_mod"];
      kernelModules = [];
    };
    kernelModules = [];
    extraModulePackages = [];

    # zram is compressed RAM: cheap to swap into and cheap to read back one
    # page at a time. The disk-tuned defaults (60 / 3) under-use it and spill
    # to /swapfile sooner than needed.
    kernel.sysctl = {
      "vm.swappiness" = 180;
      "vm.page-cluster" = 0;
    };
  };

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/63132c8d-b619-42c7-ba7d-c1a4cd8e8581";
    fsType = "ext4";
    options = ["noatime"];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/1F09-E40E";
    fsType = "vfat";
    options = ["fmask=0022" "dmask=0022"];
  };

  # Disk swapfile is the slow fallback once zram (higher priority) fills up.
  swapDevices = [
    {
      device = "/swapfile";
      size = 8192; # MiB
    }
  ];

  services.timesyncd.enable = true;

  virtualisation.vmware.guest = {
    enable = true;
    headless = true;
  };

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
