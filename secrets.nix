let
  workstation = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIjS2mkdS91J5pyTHYe+ad/8w6wf7WZPIydg/tDJMLJD root@nixos";
  elos = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN1JIqSRyq/x7GKlBGaYkmQLJ/YeQoCO4OMzozaS8hsf elos@workstation";

  allKeys = [ workstation elos ];
in
{
  "secrets/mullvad-host-account.age".publicKeys = allKeys;
  "secrets/mullvad-guest-account.age".publicKeys = allKeys;
}
