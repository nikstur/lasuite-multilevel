{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.multilevel.host;
in
{
  options.multilevel.host = {
    enable = lib.mkEnableOption "host virtualization support";
  };

  config = lib.mkIf cfg.enable {
    # Enable KVM virtualization
    virtualisation = {
      libvirtd = {
        enable = true;
        qemu = {
          package = pkgs.qemu_kvm;
          runAsRoot = false;
          swtpm.enable = true;
          ovmf = {
            enable = true;
            packages = [ pkgs.OVMFFull.fd ];
          };
        };
      };
    };

    # Add user to libvirt group
    users.users.elos.extraGroups = [ "libvirtd" ];

    # Install virtualization management tools
    environment.systemPackages = with pkgs; [
      virt-manager
      virt-viewer
      spice
      spice-gtk
      spice-protocol
      win-virtio
      win-spice
    ];

    # Enable nested virtualization
    boot.kernelModules = [ "kvm-intel" "kvm-amd" ];
    boot.extraModprobeConfig = ''
      options kvm_intel nested=1
      options kvm_amd nested=1
    '';

    # Ensure IOMMU is enabled for better VM performance
    boot.kernelParams = [ "intel_iommu=on" "iommu=pt" ];
  };
}
