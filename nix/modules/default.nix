{
  default = { imports = [ ./guest.nix ./host.nix ./image.nix ./minimization.nix ./vpn.nix ]; };
  image = ./image.nix;
  host = ./host.nix;
  guest = ./guest.nix;
  minimization = ./minimization.nix;
  vpn = ./vpn.nix;
}
