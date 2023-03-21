defmodule Mix.Tasks.PowAssent.Ecto.InstallTest do
  use PowAssent.Test.Mix.TestCase

  alias Mix.Tasks.PowAssent.Ecto.Install

  @migrations_path "migrations"
  @success_msg "PowAssent has been installed in your Ecto app!"

  setup context do
    {:ok, options: ["-r", inspect(context.repo)]}
  end

  test "default", context do
    File.cd!(context.tmp_path, fn ->
      Install.run(context.options)

      assert File.ls!("lib/pow_assent/user_identities") == ["user_identity.ex"]
      assert [_one, _two] = File.ls!(@migrations_path)

      injecting_user_message = "* injecting #{context.paths.user_path}"

      assert_received {:mix_shell, :info, [^injecting_user_message]}
      assert_received {:mix_shell, :info, [@success_msg]}

      expected_content =
        """
        defmodule PowAssent.Users.User do
          use Ecto.Schema
          use Pow.Ecto.Schema
          use PowAssent.Ecto.Schema
        """

      assert File.read!(context.paths.user_path) =~ expected_content
    end)
  end

  test "when files don't exist", context do
    File.cd!(context.tmp_path, fn ->
      File.rm_rf!(context.paths.user_path)

      assert_raise Mix.Error, "Couldn't install PowAssent! Did you run this inside your Ecto app?", fn ->
        Install.run(context.options)
      end

      assert_received {:mix_shell, :error, ["Could not find the following file(s)" <> msg]}
      assert msg =~ context.paths.user_path
    end)
  end

  test "when files can't be configured", context do
    File.cd!(context.tmp_path, fn ->
      File.write!(context.paths.user_path, "")

      Install.run(context.options)

      assert_received {:mix_shell, :error, ["Could not configure the following files:" <> msg]}
      assert msg =~ context.paths.user_path

      assert_received {:mix_shell, :info, ["To complete please do the following:" <> msg]}
      assert msg =~ "Add the `PowAssent.Ecto.Schema` macro to lib/pow_assent/users/user.ex after `use Pow.Ecto.Schema`:"
      assert msg =~ "use PowAssent.Ecto.Schema"
    end)
  end

  test "when files already configured", context do
    File.cd!(context.tmp_path, fn ->
      Install.run(context.options ++ ~w(--no-migrations --no-schema))
      Mix.shell().flush()

      Install.run(context.options)

      message = "* already configured #{context.paths.user_path}"
      assert_received {:mix_shell, :info, [^message]}
      assert_received {:mix_shell, :info, [@success_msg]}
    end)
  end

  test "raises error in app with no ecto dep", context do
    File.cd!(context.tmp_path, fn ->
      File.write!("mix.exs", """
      defmodule MissingTopLevelEctoDep.MixProject do
        use Mix.Project

        def project do
          [
            app: :missing_top_level_ecto_dep,
            deps: [
              {:ecto_dep, path: "ecto_dep/"}
            ]
          ]
        end
      end
      """)
      File.mkdir!("ecto_dep")
      File.write!("ecto_dep/mix.exs", """
      defmodule EctoDep.MixProject do
        use Mix.Project

        def project do
          [
            app: :ecto_dep,
            deps: [{:ecto_sql, ">= 0.0.0"}]
          ]
        end
      end
      """)

      Mix.Project.in_project(:missing_top_level_ecto_dep, ".", fn _ ->
        # Insurance that we do test for top level ecto inclusion
        assert Enum.any?(Mix.Dep.load_on_environment([]), fn
          %{app: :ecto_sql} -> true
          _ -> false
        end), "Ecto not loaded by dependency"

        assert_raise Mix.Error, "mix pow_assent.ecto.install can only be run inside an application directory that has :ecto or :ecto_sql as dependency", fn ->
          Install.run([])
        end
      end)
    end)
  end
end
