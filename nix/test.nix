{pkgs}:
pkgs.testers.nixosTest {
  name = "goclaw-test";
  nodes = {
    machine = {
      config,
      pkgs,
      ...
    }: {
      imports = [./module.nix];

      services.goclaw = {
        enable = true;
        gatewayPort = 18790;
      };
    };
  };

  testScript = ''
    machine.wait_for_unit("postgresql")
    machine.wait_for_unit("postgresql-setup")
    #machine.wait_for_unit("goclaw")
    machine.sleep(5)
    #machine.execute("systemctl is-active goclaw")
    #machine.wait_for_port(18790)

    # Check vector extension is installed
    #machine.succeed("psql -U postgres -tAc \"SELECT 1 FROM pg_extension WHERE extname='vector'\" | grep -q 1")
    #    print(machine.execute("psql -U postgres -c \"SELECT * FROM pg_extension WHERE extname='vector'\""))
    #   print(machine.execute("systemctl status postgresql"))
    #   print(machine.execute("systemctl status postgresql-setup"))
    print(machine.execute("systemctl status goclaw"))

    # Check static website responds
    machine.succeed("curl -f http://localhost/")

    # Check /health endpoint
    machine.succeed("curl -f http://localhost/health")
  '';
}
