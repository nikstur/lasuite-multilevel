{

  name = "multi-level";

  nodes = {
    # public = { ... }: { };
    # secret = { ... }: { };

    machine =
      { lib, ... }:
      {
        multilevel = {
          image.enable = true;
          host.enable = true;
          # guest.enable = true;
          minimization.enable = true;
        };

        virtualisation = {
          fileSystems = lib.mkForce { };
          directBoot.enable = false;
          mountHostNixStore = false;
          useEFIBoot = true;

          # Need to switch to a different GPU driver than the default one (-vga std) so that Cage can launch:
          qemu.options = [ "-vga none -device virtio-gpu-pci" ];

          memorySize = 4096;
          cores = 4;
        };
      };
  };

  testScript =
    { nodes, ... }:
    ''
      import os
      import subprocess
      import tempfile

      tmp_disk_image = tempfile.NamedTemporaryFile()

      subprocess.run([
        "${nodes.machine.virtualisation.qemu.package}/bin/qemu-img",
        "create",
        "-f",
        "qcow2",
        "-b",
        "${nodes.machine.system.build.finalImage}/${nodes.machine.image.repart.imageFile}",
        "-F",
        "raw",
        tmp_disk_image.name,
      ])

      os.environ['NIX_DISK_IMAGE'] = tmp_disk_image.name

      start_all()

      # public.wait_for_unit("multi-user.target")
      # secret.wait_for_unit("multi-user.target")
      machine.wait_for_unit("multi-user.target")

      with subtest("Running with volatile root"):
        machine.succeed("findmnt --kernel --type tmpfs /")

      with subtest("/nix/store is backed by dm-verity protected fs"):
        verity_info = machine.succeed("dmsetup info --target verity usr")
        assert "ACTIVE" in verity_info,f"unexpected verity info: {verity_info}"

        backing_device = machine.succeed("df --output=source /nix/store | tail -n1").strip()
        assert "/dev/mapper/usr" == backing_device,"unexpected backing device: {backing_device}"

      machine.wait_for_unit("public-vm.service")

      with subtest("Wait for firefox to start"):
        machine.wait_until_succeeds("pgrep firefox")
    '';

}
