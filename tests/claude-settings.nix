# Integration test for Claude settings.json assembly.
# Verifies that the security settingsFragment is properly merged
# with custom hooks into the final settings.json structure.
{
  pkgs,
  home-manager,
  ...
}:
pkgs.testers.nixosTest {
  name = "claude-settings";

  nodes.machine = {...}: {
    imports = [home-manager.nixosModules.home-manager];

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      users.testuser = {config, ...}: let
        sec = config.programs.claude-code.security.settingsFragment;
      in {
        imports = [../modules/claude-security];

        home.stateVersion = "24.11";

        programs.claude-code.security = {
          enable = true;
          hooks.notification.ntfy = {
            enable = true;
            topicFile = "/run/secrets/ntfy-topic";
          };
        };

        # Replicate the merge logic from home/common/claude.nix
        home.file.".claude/settings.json".text = builtins.toJSON {
          "$schema" = "https://json.schemastore.org/claude-code-settings.json";
          hooks = {
            PreToolUse =
              sec.hooks.PreToolUse
              ++ [
                {
                  hooks = [
                    {
                      command = "echo custom-hook";
                      type = "command";
                    }
                  ];
                  matcher = "Bash";
                }
              ];
            PostToolUse = [
              {
                hooks = [
                  {
                    command = "claude-formatter";
                    type = "command";
                  }
                ];
                matcher = "Edit|Write";
              }
            ];
            inherit (sec.hooks) Notification;
          };
          permissions = {
            inherit (sec.permissions) allow deny;
          };
          enabledPlugins = {
            "test-plugin@nix-plugins" = true;
          };
        };
      };
    };

    users.users.testuser = {
      isNormalUser = true;
      home = "/home/testuser";
    };
  };

  testScript = let
    settings = "/home/testuser/.claude/settings.json";
  in ''
    machine.wait_for_unit("multi-user.target")

    # Test 1: settings.json exists and is valid JSON
    machine.succeed("jq . ${settings}")

    # Test 2: Has $schema field
    machine.succeed("jq -e '.[\"$schema\"]' ${settings}")

    # Test 3: PreToolUse contains security bash validation hook
    machine.succeed("jq -e '.hooks.PreToolUse[] | select(.matcher == \"Bash\") | .hooks[0].command' ${settings}")

    # Test 4: PreToolUse contains both security AND custom hooks
    hook_count = int(machine.succeed("jq '.hooks.PreToolUse | length' ${settings}").strip())
    assert hook_count >= 2, f"Expected at least 2 PreToolUse hooks (security + custom), got {hook_count}"

    # Test 5: Custom hook is present alongside security hook
    machine.succeed("jq -e '.hooks.PreToolUse[] | select(.hooks[0].command == \"echo custom-hook\")' ${settings}")

    # Test 6: PostToolUse has claude-formatter hook
    machine.succeed("jq -e '.hooks.PostToolUse[] | select(.hooks[0].command == \"claude-formatter\")' ${settings}")

    # Test 7: Notification hook exists
    machine.succeed("jq -e '.hooks.Notification | length > 0' ${settings}")

    # Test 8: permissions.deny is populated from security module
    deny_count = int(machine.succeed("jq '.permissions.deny | length' ${settings}").strip())
    assert deny_count > 0, f"Expected deny list to have entries from security module, got {deny_count}"

    # Test 9: permissions.allow exists
    machine.succeed("jq -e '.permissions.allow' ${settings}")

    # Test 10: enabledPlugins field is present
    machine.succeed("jq -e '.enabledPlugins' ${settings}")

    # Test 11: Security deny entries are expanded (no literal ~)
    machine.succeed("jq -e '[.permissions.deny[] | select(contains(\"~\"))] | length == 0' ${settings}")

    # Test 12: Bash validation hook script is executable
    bash_hook_cmd = machine.succeed("jq -r '.hooks.PreToolUse[] | select(.matcher == \"Bash\") | .hooks[0].command' ${settings}").strip().split("\n")[0]
    machine.succeed(f"test -x {bash_hook_cmd}")
  '';
}
