{ config, pkgs, lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/vda";
  boot.loader.grub.useOSProber = true;

  networking.hostName = "workstation";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Paris";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "fr_FR.UTF-8";
    LC_IDENTIFICATION = "fr_FR.UTF-8";
    LC_MEASUREMENT = "fr_FR.UTF-8";
    LC_MONETARY = "fr_FR.UTF-8";
    LC_NAME = "fr_FR.UTF-8";
    LC_NUMERIC = "fr_FR.UTF-8";
    LC_PAPER = "fr_FR.UTF-8";
    LC_TELEPHONE = "fr_FR.UTF-8";
    LC_TIME = "fr_FR.UTF-8";
  };

  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  services.printing.enable = true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  users.users.elos = {
    isNormalUser = true;
    description = "ELOS";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
      kdePackages.kate
    ];
  };

  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "elos";

  programs.firefox.enable = true;

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    vim
    jq
    wget
    ghostty
    git
    curl
    tree
    ragenix
  ];

  services.openssh.enable = true;

  system.stateVersion = "25.05";

  age.identityPaths = [
    "/home/elos/.ssh/id_ed25519"
    "/etc/ssh/ssh_host_ed25519_key"
  ];
  
  age.secrets = {
    mullvad-host-account = {
      file = ../../secrets/mullvad-host-account.age;
      owner = "root";
      group = "root";
      mode = "0600";
    };
    
    mullvad-guest-account = {
      file = ../../secrets/mullvad-guest-account.age;
      owner = "root";
      group = "root";
      mode = "0600";
    };
  };


  multilevel.host.enable = true;

  multilevel.vpn = {
    enable = true;

    host = {
      enable = true;
      autoConnect = false;
      killSwitch = false;
      relayConstraints.location = "FR";
    };

    guest = {
      enable = true;
      autoConnect = true;
      killSwitch = true;
      relayConstraints.location = "CH";
    };
  };
}
