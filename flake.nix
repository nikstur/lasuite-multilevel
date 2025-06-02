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
                extraBaseModules = self.nixosModules;
              }
            );

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
