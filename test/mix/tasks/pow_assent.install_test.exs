defmodule Mix.Tasks.PowAssent.InstallTest do
  use PowAssent.Test.Mix.TestCase

  alias Mix.Tasks.PowAssent.Install

  test "generates files", context do
    File.cd!(context.tmp_path, fn ->
      Install.run([])

      assert File.ls!("lib/pow_assent/user_identities") == ["user_identity.ex"]
    end)
  end

  test "with schema name and table", context do
    File.cd!(context.tmp_path, fn ->
      Install.run(~w(Accounts.Identity identities))

      assert File.ls!("lib/pow_assent/accounts") == ["identity.ex"]
    end)
  end

  test "raises error in umbrella app", context do
    File.cd!(context.tmp_path, fn ->
      File.write!("mix.exs", """
      defmodule Umbrella.MixProject do
        use Mix.Project

        def project do
          [apps_path: "apps"]
        end
      end
      """)

      Mix.Project.in_project(:umbrella, ".", fn _ ->
        assert_raise Mix.Error, ~r/mix pow_assent.install has to be used inside an application directory/, fn ->
          Install.run([])
        end
      end)
    end)
  end

  test "raises error on invalid schema name or table", context do
    File.cd!(context.tmp_path, fn ->
      assert_raise Mix.Error, ~r/Invalid arguments/, fn ->
        Install.run(~w(UserIdentities.UserIdentity))
      end

      assert_raise Mix.Error, ~r/Expected the schema argument, "useridentities.useridentity", to be a valid module name/, fn ->
        Install.run(~w(useridentities.useridentity useridentities))
      end

      assert_raise Mix.Error, ~r/Expected the plural argument, "UserIdentities", to be all lowercase using snake_case convention/, fn ->
        Install.run(~w(UserIdentities.UserIdentity UserIdentities))
      end

      assert_raise Mix.Error, ~r/Expected the plural argument, "useridentities:", to be all lowercase using snake_case convention/, fn ->
        Install.run(~w(UserIdentities.UserIdentity useridentities:))
      end
    end)
  end
end
