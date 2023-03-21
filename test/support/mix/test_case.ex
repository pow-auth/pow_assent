defmodule PowAssent.Test.Mix.TestCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  alias Mix.Tasks.Pow.Install, as: PowInstallTask

  defmodule Repo do
    @moduledoc false

    def __adapter__, do: true
    def config, do: [priv: "./", otp_app: :pow_assent]
  end

  setup_all do
    clear_tmp_files()

    :ok
  end

  setup context do
    current_shell = Mix.shell()

    on_exit fn ->
      Mix.shell(current_shell)
    end

    Mix.shell(Mix.Shell.Process)

    context =
      context
      |> Map.put(:tmp_path, Path.join(["tmp", inspect(context.case)]))
      |> build_context()
      |> init_pow_phoenix_app_dir()

    {:ok, context}
  end

  defp clear_tmp_files, do: File.rm_rf!("tmp")

  defp build_context(context) do
    context_module = context[:context_module] || "PowAssent"
    context_path = Path.join(["lib", Macro.underscore(context_module)])
    web_module = context[:web_module] || "PowAssentWeb"
    web_path = Path.join(["lib", Macro.underscore(web_module)])

    paths =
      %{
        web_path: web_path,
        templates_path: Path.join([web_path, "templates", "pow_assent"]),
        config_path: Path.join(["config", "config.exs"]),
        endpoint_path: Path.join([web_path, "endpoint.ex"]),
        router_path: Path.join([web_path, "router.ex"]),
        user_path: Path.join([context_path, "users", "user.ex"])
      }

    Map.merge(context, %{repo: Repo, context_module: context_module, web_module: web_module, paths: paths})
  end

  defp init_pow_phoenix_app_dir(context) do
    File.rm_rf!(context.tmp_path)
    File.mkdir_p!(context.tmp_path)

    File.cd!(context.tmp_path, fn ->
      File.mkdir_p!(Path.dirname(context.paths.config_path))

      File.write!(
        context.paths.config_path,
        """
        import Config

        # Configure Mix tasks and generators
        config :#{Macro.underscore(context.context_module)},
          ecto_repos: [#{context.context_module}.Repo]

        config :#{Macro.underscore(context.context_module)},
          ecto_repos: [#{context.context_module}.Repo],
          generators: [context_app: :#{Macro.underscore(context.context_module)}]

        # Import environment specific config. This must remain at the bottom
        # of this file so it overrides the configuration defined above.
        import_config "\#{config_env()}.exs"
        """)

      File.mkdir_p!(context.paths.web_path)

      File.write!(
        context.paths.endpoint_path,
        """
        defmodule #{context.web_module}.Endpoint do
          @moduledoc false
          use Phoenix.Endpoint, otp_app: :#{Macro.underscore(context.context_module)}

          @session_options [
            store: :cookie,
            key: "_binaryid_key",
            signing_salt: "secret"
          ]

          plug Plug.RequestId
          plug Plug.Logger

          plug Plug.Parsers,
            parsers: [:urlencoded, :multipart, :json],
            pass: ["*/*"],
            json_decoder: Phoenix.json_library()

          plug Plug.MethodOverride
          plug Plug.Head
          plug Plug.Session, @session_options
          plug #{context.web_module}.Router
        end
        """)

      File.write!(
        context.paths.router_path,
        """
        defmodule #{context.web_module}.Router do
          @moduledoc false
          use #{context.web_module}, :router

          pipeline :browser do
            plug :accepts, ["html"]
            plug :fetch_session
            plug :fetch_flash
            plug :protect_from_forgery
            plug :put_secure_browser_headers
          end

          scope "/", #{context.web_module} do
            pipe_through :browser

            get "/", PageController, :index
          end
        end
        """)

      PowInstallTask.run(["-r", context.repo])

      context
    end)
  end
end
