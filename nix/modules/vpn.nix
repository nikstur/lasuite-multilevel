{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.multilevel.vpn;

  # Mullvad wrapper to use different configs for host/guest
  mullvadWrapper = name: pkgs.writeShellScriptBin "mullvad-${name}" ''
    export MULLVAD_SETTINGS_DIR="/var/lib/mullvad-${name}"
    exec ${pkgs.mullvad}/bin/mullvad "$@"
  '';
in
{
  options.multilevel.vpn = {
    enable = lib.mkEnableOption "multilevel VPN with Mullvad";

    host = {
      enable = lib.mkEnableOption "host Mullvad VPN";

      accountFile = lib.mkOption {
        type = lib.types.path;
        default = config.age.secrets.mullvad-host-account.path;
        description = "Path to encrypted Mullvad account file for host";
      };

      autoConnect = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Automatically connect host VPN on boot";
      };

      killSwitch = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable kill switch for host VPN";
      };

      relayConstraints = {
        location = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "fr";
          description = "Preferred country code for host VPN";
        };
      };
    };

    guest = {
      enable = lib.mkEnableOption "guest Mullvad VPN";

      accountFile = lib.mkOption {
        type = lib.types.path;
        default = config.age.secrets.mullvad-guest-account.path;
        description = "Path to encrypted Mullvad account file for guests";
      };

      autoConnect = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Automatically connect guest VPN on boot";
      };

      killSwitch = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable kill switch for guest VPN (recommended)";
      };

      relayConstraints = {
        location = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "se";
          description = "Preferred country code for guest VPN (should differ from host)";
        };
      };

      splitTunnel = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable split tunneling for guest VPN";
        };

        apps = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "/run/current-system/sw/bin/firefox" ];
          description = "Applications to route through guest VPN";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    # Common configuration
    {
      environment.systemPackages = with pkgs; [
        mullvad
        (mullvadWrapper "host")
        (mullvadWrapper "guest")
      ];

      # Enable IP forwarding for VPN
      boot.kernel.sysctl = {
        "net.ipv4.ip_forward" = 1;
        "net.ipv6.conf.all.forwarding" = 1;
      };
      
      # Enable Mullvad daemon
      services.mullvad-vpn.enable = true;
    }

    # Host VPN configuration
    (lib.mkIf cfg.host.enable {
      systemd.services.mullvad-host = {
        description = "Mullvad VPN for host";
        after = [ "network-online.target" "mullvad-daemon.service" ];
        wants = [ "network-online.target" ];
        requires = [ "mullvad-daemon.service" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStartPre = [
            "${pkgs.coreutils}/bin/mkdir -p /var/lib/mullvad-host"
            "${pkgs.coreutils}/bin/chmod 700 /var/lib/mullvad-host"
          ];
          ExecStart = pkgs.writeShellScript "mullvad-host-start" ''
            export MULLVAD_SETTINGS_DIR="/var/lib/mullvad-host"
            
            # Wait for account file to be available
            count=0
            while [ ! -f ${cfg.host.accountFile} ] && [ $count -lt 30 ]; do
              echo "Waiting for account file..."
              sleep 1
              count=$((count + 1))
            done
            
            if [ ! -f ${cfg.host.accountFile} ]; then
              echo "Account file not found after 30 seconds"
              exit 1
            fi

            # Wait for daemon to be ready
            count=0
            while ! ${pkgs.mullvad}/bin/mullvad version >/dev/null 2>&1 && [ $count -lt 30 ]; do
              echo "Waiting for mullvad daemon..."
              sleep 1
              count=$((count + 1))
            done

            # Login with account from agenix secret
            if ! ${pkgs.mullvad}/bin/mullvad account get >/dev/null 2>&1; then
              ACCOUNT=$(cat ${cfg.host.accountFile})
              echo "Logging in with account..."
              ${pkgs.mullvad}/bin/mullvad account login "$ACCOUNT"
            fi

            # Set relay location if specified
            ${lib.optionalString (cfg.host.relayConstraints.location != null) ''
              echo "Setting relay location to ${cfg.host.relayConstraints.location}..."
              ${pkgs.mullvad}/bin/mullvad relay set location ${cfg.host.relayConstraints.location} || \
              ${pkgs.mullvad}/bin/mullvad relay set location ${lib.toUpper cfg.host.relayConstraints.location} || \
              echo "Warning: Could not set relay location"
            ''}

            # Configure auto-connect
            ${pkgs.mullvad}/bin/mullvad auto-connect set ${if cfg.host.autoConnect then "on" else "off"}

            # Configure lockdown-mode (kill-switch)
            echo "Setting lockdown-mode to ${if cfg.host.killSwitch then "on" else "off"}..."
            ${pkgs.mullvad}/bin/mullvad lockdown-mode set ${if cfg.host.killSwitch then "on" else "off"}

            # Connect if auto-connect is enabled
            ${lib.optionalString cfg.host.autoConnect ''
              echo "Connecting..."
              ${pkgs.mullvad}/bin/mullvad connect
            ''}
          '';

          ExecStop = pkgs.writeShellScript "mullvad-host-stop" ''
            export MULLVAD_SETTINGS_DIR="/var/lib/mullvad-host"
            ${pkgs.mullvad}/bin/mullvad disconnect || true
          '';
        };
      };
    })

    # Guest VPN configuration
    (lib.mkIf cfg.guest.enable {
      systemd.services.mullvad-guest = {
        description = "Mullvad VPN for guests";
        after = [ "network-online.target" "mullvad-vpn.service" ];
        wants = [ "network-online.target" ];
        requires = [ "mullvad-vpn.service" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStartPre = [
            "${pkgs.coreutils}/bin/mkdir -p /var/lib/mullvad-guest"
            "${pkgs.coreutils}/bin/chmod 700 /var/lib/mullvad-guest"
          ];
          ExecStart = pkgs.writeShellScript "mullvad-guest-start" ''
            export MULLVAD_SETTINGS_DIR="/var/lib/mullvad-guest"
            
            # Wait for account file to be available
            count=0
            while [ ! -f ${cfg.guest.accountFile} ] && [ $count -lt 30 ]; do
              echo "Waiting for account file..."
              sleep 1
              count=$((count + 1))
            done
            
            if [ ! -f ${cfg.guest.accountFile} ]; then
              echo "Account file not found after 30 seconds"
              exit 1
            fi

            # Wait for daemon to be ready
            count=0
            while ! ${pkgs.mullvad}/bin/mullvad version >/dev/null 2>&1 && [ $count -lt 30 ]; do
              echo "Waiting for mullvad daemon..."
              sleep 1
              count=$((count + 1))
            done

            # Login with account from agenix secret
            if ! ${pkgs.mullvad}/bin/mullvad account get >/dev/null 2>&1; then
              ACCOUNT=$(cat ${cfg.guest.accountFile})
              echo "Logging in with account..."
              ${pkgs.mullvad}/bin/mullvad account login "$ACCOUNT"
            fi

            # Set relay location if specified
            ${lib.optionalString (cfg.guest.relayConstraints.location != null) ''
              echo "Setting relay location to ${cfg.guest.relayConstraints.location}..."
              ${pkgs.mullvad}/bin/mullvad relay set location ${cfg.guest.relayConstraints.location} || \
              ${pkgs.mullvad}/bin/mullvad relay set location ${lib.toUpper cfg.guest.relayConstraints.location} || \
              echo "Warning: Could not set relay location"
            ''}

            # Configure auto-connect
            ${pkgs.mullvad}/bin/mullvad auto-connect set ${if cfg.guest.autoConnect then "on" else "off"}

            # Configure lockdown-mode (kill-switch)
            echo "Setting lockdown-mode to ${if cfg.guest.killSwitch then "on" else "off"}..."
            ${pkgs.mullvad}/bin/mullvad lockdown-mode set ${if cfg.guest.killSwitch then "on" else "off"}

            # Configure split tunneling if enabled
            ${lib.optionalString cfg.guest.splitTunnel.enable ''
              ${pkgs.mullvad}/bin/mullvad split-tunnel set on
              ${lib.concatMapStringsSep "\n" (app:
                "${pkgs.mullvad}/bin/mullvad split-tunnel add ${app}"
              ) cfg.guest.splitTunnel.apps}
            ''}

            # Connect if auto-connect is enabled
            ${lib.optionalString cfg.guest.autoConnect ''
              echo "Connecting..."
              ${pkgs.mullvad}/bin/mullvad connect
            ''}
          '';

          ExecStop = pkgs.writeShellScript "mullvad-guest-stop" ''
            export MULLVAD_SETTINGS_DIR="/var/lib/mullvad-guest"
            ${pkgs.mullvad}/bin/mullvad disconnect || true
          '';
        };
      };
    })

    # Isolation between host and guest VPNs
    {
      networking.firewall = lib.mkIf (cfg.host.enable && cfg.guest.enable) {
        extraCommands = ''
          # Get Mullvad interfaces (they're usually named wg-mullvad or similar)
          HOST_IFACE=$(ip link show | grep -o 'wg[^:]*' | grep -v guest | head -1) || true
          GUEST_IFACE=$(ip link show | grep -o 'wg[^:]*' | grep guest | head -1) || true

          # Block traffic between host and guest VPN interfaces if they exist
          if [ -n "$HOST_IFACE" ] && [ -n "$GUEST_IFACE" ]; then
            iptables -I FORWARD -i "$HOST_IFACE" -o "$GUEST_IFACE" -j DROP
            iptables -I FORWARD -i "$GUEST_IFACE" -o "$HOST_IFACE" -j DROP
          fi
        '';
      };
    }
  ]);
}
