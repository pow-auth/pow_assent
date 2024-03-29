defmodule Mix.Tasks.PowAssent.Ecto.Gen.Schema do
  @shortdoc "Generates user identity schema"

  @moduledoc """
  Generates a user identity schema.

      mix pow_assent.ecto.gen.schema -r MyApp.Repo

      mix pow_assent.ecto.gen.schema -r MyApp.Repo Accounts.Identity identities

  This generator will add a schema module file in
  `lib/my_app/user_identities/user_identity.ex`.

  ## Arguments

    * `--binary-id` - use binary id for primary key and references
    * `--context-app` - context app to use for path and module names
  """
  use Mix.Task

  alias PowAssent.Ecto.UserIdentities.Schema.Module, as: SchemaModule
  alias Mix.{Generator, Pow, PowAssent}

  @switches [context_app: :string, binary_id: :boolean]
  @default_opts [binary_id: false]
  @mix_task "pow_assent.ecto.gen.schema"

  @impl true
  def run(args) do
    Pow.no_umbrella!(@mix_task)

    args
    |> Pow.parse_options(@switches, @default_opts)
    |> parse()
    |> create_schema_file()
  end

  defp parse({config, parsed, _invalid}) do
    parsed
    |> PowAssent.validate_schema_args!(@mix_task)
    |> Map.merge(config)
  end

  defp create_schema_file(%{binary_id: binary_id, schema_name: schema_name, schema_plural: schema_plural} = config) do
    context_app  = Map.get(config, :context_app) || Pow.otp_app()
    context_base = Pow.app_base(context_app)
    schema       = SchemaModule.new(context_base, schema_name, schema_plural, binary_id: binary_id)
    content      = SchemaModule.gen(schema)
    dir_name     = dir_name(schema_name)
    file_name    = file_name(schema.module)

    context_app
    |> Pow.context_lib_path(dir_name)
    |> maybe_create_directory()
    |> Path.join(file_name)
    |> ensure_unique()
    |> Generator.create_file(content)
  end

  defp dir_name(schema_name) do
    schema_name
    |> String.split(".")
    |> Enum.slice(0..-2//1)
    |> Enum.join(".")
    |> Macro.underscore()
  end

  defp file_name(module) do
    module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
    |> Kernel.<>(".ex")
  end

  defp maybe_create_directory(path) do
    Generator.create_directory(path)

    path
  end

  defp ensure_unique(path) do
    path
    |> File.exists?()
    |> case do
      false -> path
      _     -> Mix.raise("schema file can't be created, there is already a schema file in #{path}.")
    end
  end
end
