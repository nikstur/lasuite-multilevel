{ config, pkgs, lib, modulesPath, ... }:
{
  imports = [
    # Use QEMU guest for VM
    "${modulesPath}/profiles/qemu-guest.nix"
  ];

  # Enable the multilevel modules for a minimal kiosk
  multilevel = {
    guest.enable = true;       # Kiosk mode with Firefox
    image.enable = true;       # Immutable image
    minimization.enable = true; # Strip down to essentials
  };

  # Basic networking for the VM
  networking.useDHCP = lib.mkDefault true;

  # Minimal boot configuration for VMs
  boot.initrd.availableKernelModules = [ "virtio_pci" "virtio_scsi" "ahci" "sd_mod" ];
  boot.kernelModules = [ ];
  
  # VM-specific hardware config
  hardware.enableRedistributableFirmware = lib.mkDefault true;
  
  system.stateVersion = "25.05";
}
