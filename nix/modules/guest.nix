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
    users = {
      users.cage = {
        isSystemUser = true;
        group = "cage";
        home = "/var/lib/kiosk";
        createHome = true;
      };
      groups.cage = { };
    };

    services.cage = {
      enable = true;
      user = "cage";
      program = "${pkgs.firefox}/bin/firefox";
    };
  };
}
