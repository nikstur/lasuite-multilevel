{
  default = { imports = [ ./guest.nix ./host.nix ./image.nix ./minimization.nix ]; };
  image = ./image.nix;
  host = ./host.nix;
  guest = ./guest.nix;
  minimization = ./minimization.nix;
}
