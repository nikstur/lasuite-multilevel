{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.multilevel.host;

  qemu-common = import "${pkgs.path}/nixos/lib/qemu-common.nix" { inherit lib pkgs; };

  evalConfig =
    module:
    (import "${pkgs.path}/nixos/lib/eval-config.nix" {
      modules = [
        (
          { ... }:
          {
            nixpkgs = {
              hostPlatform = pkgs.stdenv.hostPlatform;
              pkgs = pkgs;
            };
            system.stateVersion = config.system.stateVersion;
          }
        )
      ] ++ [ module ];
      system = null;
    }).config;

  publicGuest = evalConfig ({
    imports = [
      ./image.nix
      ./minimization.nix
      ./guest.nix
    ];

    multilevel = {
      image.enable = true;
      minimization.enable = true;
      guest.enable = true;
    };
  });
in
{
  options.multilevel.host = {
    enable = lib.mkEnableOption "host";
  };

  config = lib.mkIf cfg.enable {
    users = {
      users.kiosk = {
        isNormalUser = true;
        group = "kiosk";
      };
      groups.kiosk = { };
    };

    services.getty.autologinUser = "kiosk";

    programs.sway = {
      enable = true;
      wrapperFeatures.gtk = true;
    };

    systemd.services.sway = {
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        User = "kiosk";
        Group = "kiosk";
        ExecStart = "${pkgs.sway}/bin/sway";
      };
    };

    systemd.services.public-vm = {
      description = "Public VM";
      wantedBy = [ "multi-user.target" ];
      requires = [ "sway.service" ];
      after = [ "sway.service" ];
      script = ''
        cp ${cfg.efi.variables} "$NIX_EFI_VARS

        exec ${qemu-common.qemuBinary config.virtualisation.qemu.package} \
          -machine accel=kvm:tcg \
          -cpu max \
          -name machine \
          -m 2048 \
          -smp 2 \
          -device virtio-rng-pci \
          -blockdev "driver=file,filename=${publicGuest.system.build.finalImage}/${publicGuest.image.repart.imageFile},node-name=drive1,read-only=true" \
          -device "virtio-blk-pci,bootindex=1,drive=drive1" \
          -drive if=pflash,format=raw,unit=0,readonly=on,file=${cfg.efi.firmware}
          -drive if=pflash,format=raw,unit=1,readonly=off,file=$NIX_EFI_VARS
          -vga none \
          -device virtio-gpu-pci
      '';
    };
  };
}
