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

    programs.firefox = {
      enable = true;
      policies = {
        DisableFirefoxStudies = true;
        DisableTelemetry = true;
        DisableSetDesktopBackground = true;
        DisableDeveloperTools = true;
        BlockAboutConfig = true;
      };
    };

    services.cage = {
      enable = true;
      user = "cage";
      program = ''
        ${config.programs.firefox.package}/bin/firefox \
          --kiosk \
          --private-window \
          lasuite.numerique.gouv.fr
      '';
    };
  };
}
