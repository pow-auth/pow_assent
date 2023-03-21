defmodule Mix.Tasks.PowAssent.Phoenix.InstallTest do
  use PowAssent.Test.Mix.TestCase

  alias Mix.Tasks.PowAssent.Phoenix.Install

  @options     []
  @success_msg "PowAssent has been installed in your Phoenix app!"

  test "default", context do
    File.cd!(context.tmp_path, fn ->
      Install.run(@options)

      refute File.exists?(context.paths.templates_path)

      injecting_router_path_message = "* injecting #{context.paths.router_path}"

      assert_received {:mix_shell, :info, [^injecting_router_path_message]}
      assert_received {:mix_shell, :info, [@success_msg]}

      expected_router_head =
        """
          use Pow.Phoenix.Router
          use PowAssent.Phoenix.Router
        """

      expected_router_pipeline =
        """
          pipeline :skip_csrf_protection do
            plug :accepts, ["html"]
            plug :fetch_session
            plug :fetch_flash
            plug :put_secure_browser_headers
          end

          scope "/" do
        """

      expected_router_authorization_scope =
        """
          scope "/" do
            pipe_through :skip_csrf_protection

            pow_assent_authorization_post_callback_routes()
          end

          scope "/" do
        """

      expected_router_updated_scope =
        """
          scope "/" do
            pipe_through :browser

            pow_routes()
            pow_assent_routes()
          end
        """

      assert File.read!(context.paths.router_path) =~ expected_router_head
      assert File.read!(context.paths.router_path) =~ expected_router_pipeline
      assert File.read!(context.paths.router_path) =~ expected_router_authorization_scope
      assert File.read!(context.paths.router_path) =~ expected_router_updated_scope
    end)
  end

  test "when files don't exist", context do
    File.cd!(context.tmp_path, fn ->
      File.rm_rf!(context.paths.router_path)

      assert_raise Mix.Error, "Couldn't install PowAssent! Did you run this inside your Phoenix app?", fn ->
        Install.run(@options)
      end

      assert_received {:mix_shell, :error, ["Could not find the following file(s)" <> msg]}
      assert msg =~ context.paths.router_path
    end)
  end

  test "when files can't be configured", context do
    File.cd!(context.tmp_path, fn ->
      File.write!(context.paths.router_path, "")

      Install.run(@options)

      assert_received {:mix_shell, :error, ["Could not configure the following files:" <> msg]}
      assert msg =~ context.paths.router_path

      assert_received {:mix_shell, :info, ["To complete please do the following:" <> msg]}
      assert msg =~ "Update `lib/pow_assent_web/router.ex` with the PowAssent routes:"
      assert msg =~ "use PowAssent.Phoenix.Router"
      assert msg =~ "pipeline :skip_csrf_protection do"
      assert msg =~ "pow_assent_authorization_post_callback_routes()"
      assert msg =~ "pow_assent_routes()"
    end)
  end

  test "when files already configured", context do
    File.cd!(context.tmp_path, fn ->
      Install.run(@options)
      Mix.shell().flush()

      Install.run(@options)

      message = "* already configured #{context.paths.router_path}"
      assert_received {:mix_shell, :info, [^message]}
      assert_received {:mix_shell, :info, [@success_msg]}
    end)
  end

  test "with templates", context do
    options = @options ++ ~w(--templates)

    File.cd!(context.tmp_path, fn ->
      Install.run(options)

      assert File.exists?(context.paths.templates_path)
      assert [_one] = File.ls!(context.paths.templates_path)
    end)
  end

  test "raises error in app with no top level phoenix dep", context do
    File.cd!(context.tmp_path, fn ->
      File.write!("mix.exs", """
      defmodule MissingTopLevelPhoenixDep.MixProject do
        use Mix.Project

        def project do
          [
            app: :missing_top_level_phoenix_dep,
            deps: [
              {:phoenix_dep, path: "dep/"}
            ]
          ]
        end
      end
      """)
      File.mkdir!("dep")
      File.write!("dep/mix.exs", """
      defmodule PhoenixDep.MixProject do
        use Mix.Project

        def project do
          [
            app: :phoenix_dep,
            deps: [
              {:phoenix, ">= 0.0.0"}
            ]
          ]
        end
      end
      """)

      Mix.Project.in_project(:missing_top_level_phoenix_dep, ".", fn _ ->
        # Insurance that we do test for top level phoenix inclusion
        assert Enum.any?(Mix.Dep.load_on_environment([]), fn
          %{app: :phoenix} -> true
          _ -> false
        end), "Phoenix not loaded by dependency"

        assert_raise Mix.Error, "mix pow_assent.phoenix.install can only be run inside an application directory that has :phoenix as dependency", fn ->
          Install.run(@options)
        end
      end)
    end)
  end
end
