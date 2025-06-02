{
  description = "LaSuite Multi-Level";

  inputs = {

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    systems.url = "github:nix-systems/default";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    pre-commit-hooks-nix = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };

  };

  outputs =
    inputs@{
      self,
      flake-parts,
      systems,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { moduleWithSystem, ... }:
      {
        systems = import systems;

        imports = [
          inputs.flake-parts.flakeModules.easyOverlay
          inputs.pre-commit-hooks-nix.flakeModule
        ];

        flake = {
          nixosModules = import ./nix/modules;
          nixosConfigurations = import ./nix/configurations;
        };

        perSystem =
          {
            config,
            system,
            pkgs,
            lib,
            ...
          }:
          {
            checks = (
              import ./nix/tests {
                inherit pkgs;
                extraBaseModules = import ./nix/modules;
              }
            );

            packages = {
              start-ch = pkgs.writeScriptBin "start-ch" ''
                exec ${pkgs.cloud-hypervisor}/bin/cloud-hypervisor \
                  --kernel "$TOPLEVEL/kernel" \
                  --initramfs "$TOPLEVEL/initrd" \
                  --cmdline "init=$TOPLEVEL/init $(cat $TOPLEVEL/kernel-params)" \
                  --disk "path=$FINAL_IMAGE,readonly=true" \
                  --cpus "boot=2" \
                  --memory "size=2048M"
              '';
              start-qemu = pkgs.writeScriptBin "start-qemu" ''
                exec ${pkgs.qemu}/bin/qemu-system-x86_64 \
                  -machine accel=kvm:tcg \
                  -cpu max \
                  -name machine \
                  -m 2048 \
                  -smp 2 \
                  -device virtio-rng-pci \
                  -kernel "$TOPLEVEL/kernel" \
                  -initrd "$TOPLEVEL/initrd" \
                  -append "init=$TOPLEVEL/init $(cat $TOPLEVEL/kernel-params)" \
                  -drive "file=$FINAL_IMAGE,id=drive1,readonly=on" \
                  -device virtio-blk-pci,bootindex=1,drive=drive1,readonly=on \
                  -vga none \
                  -device virtio-gpu-pci
              '';
            };

            pre-commit = {
              check.enable = true;

              settings = {
                hooks = {
                  nixfmt-rfc-style = {
                    enable = true;
                  };
                };
              };
            };

            devShells.default = pkgs.mkShell {
              shellHook = ''
                ${config.pre-commit.installationScript}
              '';
            };

          };
      }
    );
}
