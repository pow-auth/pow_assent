defmodule Mix.Tasks.PowAssent.Phoenix.Install do
  @shortdoc "Prints instructions for setting up PowAssent with Phoenix"

  @moduledoc """
  Prints instructions fo setting up PowAssent with Phoenix.

      mix pow_assent.phoenix.install -r MyApp.Repo

      mix pow_assent.phoenix.install -r MyApp.Repo --context-app :my_app

  Templates are only generated when `--templates` argument is provided.

  See `Mix.Tasks.PowAssent.Phoenix.Gen.Templates` and
  `Mix.Tasks.PowAssent.Extension.Phoenix.Gen.Templates` for more.

  ## Arguments

    * `--context-app` - app to use for path and module names
    * `--templates` - generate templates
    * `--extension` - extensions to generate templates for
  """
  use Mix.Task

  alias Mix.{Pow, Pow.Phoenix}
  alias Mix.Tasks.PowAssent.Phoenix.Gen.Templates, as: PhoenixTemplatesTask

  @switches [context_app: :string, templates: :boolean]
  @default_opts [templates: false]
  @mix_task "pow_assent.phoenix.install"

  @impl true
  def run(args) do
    Pow.no_umbrella!(@mix_task)
    Pow.ensure_phoenix!(@mix_task, args)

    args
    |> Pow.parse_options(@switches, @default_opts)
    |> parse_structure()
    |> print_shell_instructions()
    |> maybe_run_gen_templates(args)
  end

  defp parse_structure({config, _parsed, _invalid}) do
    Map.put(config, :structure, Phoenix.parse_structure(config))
  end

  defp print_shell_instructions(%{structure: structure} = config) do
    [
      phoenix_router_file_injection(structure)
    ]
    |> Pow.inject_files()
    |> case do
      :ok ->
        Mix.shell().info("PowAssent has been installed in your Phoenix app!")
        config

      :error ->
        Mix.raise "Couldn't install PowAssent! Did you run this inside your Phoenix app?"
    end
  end

  defp phoenix_router_file_injection(structure) do
    file = Path.expand("#{structure.web_prefix}/router.ex")

    router_use_content = "  use PowAssent.Phoenix.Router"

    router_pipeline_content =
      """
        pipeline :skip_csrf_protection do
          plug :accepts, ["html"]
          plug :fetch_session
          plug :fetch_flash
          plug :put_secure_browser_headers
        end
      """

    router_scope_content =
      """
        scope "/" do
          pipe_through :skip_csrf_protection

          pow_assent_authorization_post_callback_routes()
        end
      """

    router_routes_macro = "    pow_assent_routes()"

    %{
      file: file,
      injections: [
        %{
          content: router_use_content,
          test: "use PowAssent.Phoenix.Router",
          needle: "use Pow.Phoenix.Router"
        },
        %{
          content: router_pipeline_content,
          test: "pipeline :skip_csrf_protection do",
          needle: "scope \"/\"",
          prepend: true
        },
        %{
          content: router_scope_content,
          test: "pow_assent_authorization_post_callback_routes()",
          needle: "scope \"/\"",
          prepend: true
        },
        %{
          content: router_routes_macro,
          test: "pow_assent_routes()",
          needle: "pow_routes()"
        }
      ],
      instructions:
        """
        Update `#{Path.relative_to_cwd(file)}` with the PowAssent routes:

        defmodule #{inspect(structure.web_module)}.Router do
          use #{inspect(structure.web_module)}, :router
          use Pow.Phoenix.Router
        #{router_use_content}

          # ...

        #{router_pipeline_content}

          # ...

        #{router_scope_content}

          scope "/" do
            pipe_through :browser

            pow_routes()
        #{router_routes_macro}
          end

          # ...
        end
        """
    }
  end

  defp maybe_run_gen_templates(%{templates: true} = config, args) do
    PhoenixTemplatesTask.run(args)

    config
  end
  defp maybe_run_gen_templates(config, _args), do: config
end
