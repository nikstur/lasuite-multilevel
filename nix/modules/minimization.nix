{
  lib,
  config,
  ...
}:
let
  cfg = config.multilevel.minimization;
in
{
  options.multilevel.minimization = {
    enable = lib.mkEnableOption "minimization";
  };

  config = lib.mkIf cfg.enable {
    nix.enable = false;

    system = {
      # Currently the kernel is broken on master
      # etc.overlay.enable = true;
      switch.enable = false;
      # xdg-utils depend on Perl
      # forbiddenDependenciesRegexes = [ "perl" ];
      tools.nixos-generate-config.enable = lib.mkDefault false;
    };

    i18n.supportedLocales = [ (config.i18n.defaultLocale + "/UTF-8") ];

    fonts = {
      fontconfig.enable = lib.mkDefault false;
    };

    documentation = {
      enable = lib.mkDefault false;
      doc.enable = lib.mkDefault false;
      info.enable = lib.mkDefault false;
      man.enable = lib.mkDefault false;
      nixos.enable = lib.mkDefault false;
    };

    environment = {
      defaultPackages = lib.mkDefault [ ];
      stub-ld.enable = lib.mkDefault false;
    };

    programs = {
      command-not-found.enable = lib.mkDefault false;
      less.lessopen = lib.mkDefault null;
      nano.enable = lib.mkDefault false;
    };

    boot = {
      initrd.systemd.enable = lib.mkDefault true;
      enableContainers = lib.mkDefault false;
      loader.grub.enable = lib.mkDefault false;
    };

    security = {
      sudo.enable = lib.mkDefault false;
      # Cage seems to use PAM (and thus suid binaries)
      # enableWrappers = lib.mkDefault false;
    };

    xdg = {
      autostart.enable = lib.mkDefault false;
      icons.enable = lib.mkDefault false;
      menus.enable = lib.mkDefault false;
      mime.enable = lib.mkDefault false;
      sounds.enable = lib.mkDefault false;
    };

    services = {
      userborn.enable = true;
      udisks2.enable = lib.mkDefault false;
    };

    systemd.enableEmergencyMode = lib.mkDefault false;
  };
}
