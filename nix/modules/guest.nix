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
    enable = lib.mkEnableOption "guest kiosk mode";
    
    vpnOnly = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Force all network traffic through VPN";
    };
    
    allowedSites = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "lasuite.numerique.gouv.fr" ];
      description = "Allowed sites when not using VPN";
    };
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
        # Network restrictions
        WebsiteFilter = lib.mkIf (!cfg.vpnOnly && cfg.allowedSites != []) {
          Block = [ "*" ];
          Exceptions = cfg.allowedSites;
        };
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
    
    # Network restrictions for kiosk
    networking.firewall = lib.mkIf cfg.vpnOnly {
      enable = true;
      
      # Only allow traffic through VPN interface
      extraCommands = ''
        # Drop all traffic not going through VPN
        iptables -I OUTPUT -o lo -j ACCEPT
        iptables -I OUTPUT -o wg-guest -j ACCEPT
        iptables -I OUTPUT -m owner --uid-owner cage -j DROP
      '';
      
      extraStopCommands = ''
        iptables -D OUTPUT -o lo -j ACCEPT 2>/dev/null || true
        iptables -D OUTPUT -o wg-guest -j ACCEPT 2>/dev/null || true
        iptables -D OUTPUT -m owner --uid-owner cage -j DROP 2>/dev/null || true
      '';
    };
    
    # Auto-enable guest VPN when in guest mode
    multilevel.vpn.guest.enable = lib.mkDefault true;
  };
}
