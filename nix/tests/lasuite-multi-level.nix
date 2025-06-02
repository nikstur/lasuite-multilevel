{

  name = "multi-level";

  nodes = {
    # public = { ... }: { };
    # secret = { ... }: { };

    machine =
      { ... }:
      {
      };
  };

  testScript = ''
    start_all()
    # public.wait_for_unit("multi-user.target")
    # secret.wait_for_unit("multi-user.target")
    machine.wait_for_unit("multi-user.target")
  '';

}
