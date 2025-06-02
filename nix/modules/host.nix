{
  lib,
  config,
  ...
}:

let
  cfg = config.multilevel.host;
in
{
  options.multilevel.host = {
    enable = lib.mkEnableOption "host";
  };

  config = lib.mkIf cfg.enable {

  };
}
