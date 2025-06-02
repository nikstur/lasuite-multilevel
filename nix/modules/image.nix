{
  config,
  lib,
  modulesPath,
  ...
}:
let
  inherit (config.image.repart.verityStore) partitionIds;
in
{
  imports = [ "${modulesPath}/image/repart.nix" ];

  fileSystems = {
    "/" = {
      fsType = "tmpfs";
      options = [ "mode=0755" ];
    };

    # bind-mount the store from the verity protected /usr partition
    "/nix/store" = {
      device = "/usr/nix/store";
      options = [ "bind" ];
    };
  };

  image.repart = {
    verityStore = {
      enable = true;
      # by default the module works with systemd-boot, for simplicity this test directly boots the UKI
      ukiPath = "/EFI/BOOT/BOOT${lib.toUpper config.nixpkgs.hostPlatform.efiArch}.EFI";
    };

    name = "appliance-verity-store-image";

    partitions = {
      ${partitionIds.esp} = {
        # the UKI is injected into this partition by the verityStore module
        repartConfig = {
          Type = "esp";
          Format = "vfat";
          SizeMinBytes = "64M";
        };
      };
      ${partitionIds.store-verity}.repartConfig = {
        Minimize = "best";
      };
      ${partitionIds.store}.repartConfig = {
        Minimize = "best";
      };
    };
  };

  boot = {
    loader.grub.enable = false;
    initrd.systemd.enable = true;
  };

  system.image = {
    id = "nixos-appliance";
    version = "1";
  };

  # don't create /usr/bin/env
  # this would require some extra work on read-only /usr
  # and it is not a strict necessity
  system.activationScripts.usrbinenv = lib.mkForce "";
}
