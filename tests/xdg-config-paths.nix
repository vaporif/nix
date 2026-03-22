# Integration test for XDG config path substitution.
# Verifies that @configPath@ and @agentDeckPath@ placeholders
# are replaced in wezterm and yazi configs at build time.
{
  pkgs,
  home-manager,
  inputs,
  ...
}:
pkgs.testers.nixosTest {
  name = "xdg-config-paths";

  nodes.machine = {...}: {
    imports = [home-manager.nixosModules.home-manager];

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      extraSpecialArgs = {inherit inputs;};
      users.testuser = {...}: {
        imports = [
          ../modules/options.nix
          ../home/common/xdg.nix
        ];

        home.stateVersion = "24.11";

        custom = {
          user = "testuser";
          system = "aarch64-linux";
          configPath = "/home/testuser/.config/nix-darwin";
        };
      };
    };

    users.users.testuser = {
      isNormalUser = true;
      home = "/home/testuser";
    };
  };

  testScript = let
    weztermConf = "/home/testuser/.config/wezterm/wezterm.lua";
    yaziKeymap = "/home/testuser/.config/yazi/keymap.toml";
  in ''
    machine.wait_for_unit("multi-user.target")

    # Test 1: wezterm config exists
    machine.succeed("test -f ${weztermConf}")

    # Test 2: No unreplaced @configPath@ in wezterm config
    machine.fail("grep -q '@configPath@' ${weztermConf}")

    # Test 3: No unreplaced @agentDeckPath@ in wezterm config
    machine.fail("grep -q '@agentDeckPath@' ${weztermConf}")

    # Test 4: Substituted configPath value is present in wezterm config
    machine.succeed("grep -q '/home/testuser/.config/nix-darwin' ${weztermConf}")

    # Test 5: yazi keymap exists
    machine.succeed("test -f ${yaziKeymap}")

    # Test 6: No unreplaced @configPath@ in yazi keymap
    machine.fail("grep -q '@configPath@' ${yaziKeymap}")

    # Test 7: Substituted configPath value is present in yazi keymap
    machine.succeed("grep -q '/home/testuser/.config/nix-darwin' ${yaziKeymap}")
  '';
}
