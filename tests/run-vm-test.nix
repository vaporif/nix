# Wrapper around pkgs.testers.nixosTest that drops the `kvm` scheduling
# constraint. GitHub-hosted ARM runners have no /dev/kvm, so `nix flake check`
# otherwise fails with "missing system features: {kvm}". The test driver runs
# QEMU with accel=kvm:tcg, so KVM is still used wherever it exists (the NixOS
# VMs locally); CI just falls back to slower TCG software emulation.
pkgs: testConfig:
(pkgs.testers.nixosTest testConfig).overrideTestDerivation (old: {
  requiredSystemFeatures = pkgs.lib.remove "kvm" old.requiredSystemFeatures;
})
