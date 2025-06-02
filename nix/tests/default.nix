{ pkgs, extraBaseModules }:

let
  runTest =
    module:
    pkgs.testers.runNixOSTest {
      imports = [ module ];
      globalTimeout = 5 * 60;
      extraBaseModules = {
        # imports = builtins.attrValues extraBaseModules;
        imports = [
          ../modules/host.nix
          ../modules/guest.nix
          ../modules/image.nix
        ];
      };
    };
in

{
  lasuite-multi-level = runTest ./lasuite-multi-level.nix;
}
