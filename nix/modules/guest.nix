{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.multilevel.guest;
in
{
  options.multilevel.guest = {
    enable = lib.mkEnableOption "guest";
  };

  config = lib.mkIf cfg.enable {
    services.cage = {
      enable = true;
      program = "${pkgs.firefox}/bin/firefox";
    };
  };
}
