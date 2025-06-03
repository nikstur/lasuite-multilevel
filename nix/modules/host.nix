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
    
    vpnPassthrough = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow VMs to use their own VPN connections";
    };
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
    
    # Network isolation for VMs
    networking = {
      bridges = {
        "virbr-isolated" = {
          interfaces = [];
        };
      };
      
      interfaces = {
        "virbr-isolated" = {
          ipv4.addresses = [{
            address = "192.168.100.1";
            prefixLength = 24;
          }];
        };
      };
      
      nat = {
        enable = true;
        internalInterfaces = [ "virbr-isolated" ];
      };
      
      firewall = {
        interfaces."virbr-isolated" = {
          allowedUDPPorts = [ 53 67 ]; # DNS and DHCP
          allowedTCPPorts = [ ];
        };
      };
    };
    
    # DHCP server for isolated VM network
    services.dnsmasq = {
      enable = true;
      settings = {
        interface = "virbr-isolated";
        bind-interfaces = true;
        dhcp-range = "192.168.100.10,192.168.100.100,12h";
        # Prevent DNS leaks from VMs to host VPN
        no-resolv = true;
        server = [ "1.1.1.1" "8.8.8.8" ];
      };
    };
  };
}
