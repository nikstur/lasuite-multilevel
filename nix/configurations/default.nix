{ self, inputs, ... }:
{
  workstation = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";

    modules = [
      # IMPORTANT: Import agenix module
      inputs.agenix.nixosModules.default
      
      # Import your workstation configuration
      ./workstation.nix

      # Include your custom modules
      self.nixosModules.default

      # Pass inputs to your modules
      {
        _module.args = {
          inherit inputs self;
        };
      }
    ];
  };
}
