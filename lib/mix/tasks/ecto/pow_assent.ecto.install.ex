defmodule Mix.Tasks.PowAssent.Ecto.Install do
  @shortdoc "Generates user identity schema and migration file"

  @moduledoc """
  Generates user identity schema and migration file.

      mix pow_assent.ecto.install -r MyApp.Repo

      mix pow_assent.ecto.install -r MyApp.Repo Accounts.Identity identities

  See `Mix.Tasks.PowAssent.Ecto.Gen.Schema` and
  `Mix.Tasks.PowAssent.Ecto.Gen.Migration` for more.

  ## Arguments

    * `--no-migrations` - don't generate migration files
    * `--no-schema` - don't generate schema file
  """
  use Mix.Task

  alias Mix.Tasks.PowAssent.Ecto.Gen.Migration, as: MigrationTask
  alias Mix.Tasks.PowAssent.Ecto.Gen.Schema, as: SchemaTask
  alias Mix.{Pow, PowAssent}

  @switches [migrations: :boolean, schema: :boolean]
  @default_opts [migrations: true, schema: true]
  @mix_task "pow_assent.ecto.install"

  @impl true
  def run(args) do
    Pow.no_umbrella!(@mix_task)
    Pow.ensure_ecto!(@mix_task, args)

    args
    |> Pow.parse_options(@switches, @default_opts)
    |> parse()
    |> maybe_run_gen_migration(args)
    |> maybe_run_gen_schema(args)
    |> parse_structure()
    |> print_shell_instructions()
  end

  defp parse({config, parsed, _invalid}) do
    PowAssent.validate_schema_args!(parsed, @mix_task)

    config
  end

  defp maybe_run_gen_migration(%{migrations: true} = config, args) do
    MigrationTask.run(args)

    config
  end
  defp maybe_run_gen_migration(config, _args), do: config

  defp maybe_run_gen_schema(%{schema: true} = config, args) do
    SchemaTask.run(args)

    config
  end
  defp maybe_run_gen_schema(config, _args), do: config

  defp parse_structure(config) do
    context_app  = Map.get(config, :context_app) || Pow.otp_app()
    context_base = Pow.app_base(context_app)
    user_module = Module.concat([context_base, "Users.User"])
    user_file = Path.join(["lib", "#{context_app}", "users", "user.ex"])

    Map.put(config, :structure, %{context_app: context_app, user_module: user_module, user_file: user_file})
  end

  defp print_shell_instructions(%{structure: structure} = config) do
    [
      user_file_injection(structure)
    ]
    |> Pow.inject_files()
    |> case do
      :ok ->
        Mix.shell().info("PowAssent has been installed in your Ecto app!")
        config

      :error ->
        Mix.raise "Couldn't install PowAssent! Did you run this inside your Ecto app?"
    end
  end

  defp user_file_injection(structure) do
    file = Path.expand(structure.user_file)

    %{
      file: file,
      injections: [
        %{
          content: "  use PowAssent.Ecto.Schema",
          test: "use PowAssent.Ecto.Schema",
          needle: "use Pow.Ecto.Schema"
        }
      ],
      instructions:
        """
        Add the `PowAssent.Ecto.Schema` macro to #{Path.relative_to_cwd(file)} after `use Pow.Ecto.Schema`:

        defmodule #{inspect(structure.user_module)} do
          use Ecto.Schema
          use Pow.Ecto.Schema
          use PowAssent.Ecto.Schema

        # ...
        """
    }
  end
end
