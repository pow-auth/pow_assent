defmodule Mix.Tasks.PowAssent.Ecto.Gen.Schema do
  @shortdoc "Generates user identity schema"

  @moduledoc """
  Generates a user identity schema.

      mix pow.ecto.gen.schema -r MyApp.Repo
  """
  use Mix.Task

  alias PowAssent.Ecto.UserIdentities.Schema.Module, as: SchemaModule
  alias Mix.{Generator, Pow}

  @switches [context_app: :string, binary_id: :boolean]
  @default_opts [binary_id: false]

  @doc false
  def run(args) do
    Pow.no_umbrella!("pow_assent.ecto.gen.schema")

    args
    |> Pow.parse_options(@switches, @default_opts)
    |> create_schema_file()
  end

  defp create_schema_file(%{binary_id: binary_id} = config) do
    context_app  = Map.get(config, :context_app, Pow.context_app())
    context_base = Pow.context_base(context_app)

    base_name = "user_identity.ex"
    content   = SchemaModule.gen(context_base, module: "UserIdentities.UserIdentity", binary_id: binary_id)

    context_app
    |> Pow.context_lib_path("user_identities")
    |> maybe_create_directory()
    |> Path.join(base_name)
    |> ensure_unique()
    |> Generator.create_file(content)
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
