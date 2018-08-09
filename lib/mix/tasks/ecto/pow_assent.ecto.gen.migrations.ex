defmodule Mix.Tasks.PowAssent.Ecto.Gen.Migration do
  @shortdoc "Generates user identities migration file"

  @moduledoc """
  Generates a user identity migrations file.

      mix pow_assent.ecto.gen.migration -r MyApp.Repo

      mix pow_assent.ecto.gen.migration -r MyApp.Repo CustomUserIdentity custom_user_identity
  """
  use Mix.Task

  alias PowAssent.Ecto.UserIdentities.Schema.Migration, as: UserIdentitiesMigration
  alias Mix.{Ecto, Pow, Pow.Ecto.Migration}

  @switches [binary_id: :boolean, users_table: :string]
  @default_opts [binary_id: false, users_table: "users"]

  @doc false
  def run(args) do
    Pow.no_umbrella!("pow_assent.ecto.gen.migration")

    args
    |> Pow.parse_options(@switches, @default_opts)
    |> parse()
    |> create_migrations_files(args)
  end

  defp parse({config, parsed, _invalid}) do
    case parsed do
      [_schema_name, schema_plural | _rest] ->
        Map.merge(config, %{schema_plural: schema_plural})

      _ ->
        config
    end
  end

  defp create_migrations_files(config, args) do
    args
    |> Ecto.parse_repo()
    |> Enum.map(&Ecto.ensure_repo(&1, args))
    |> Enum.map(&Map.put(config, :repo, &1))
    |> Enum.each(&create_migration_files/1)
  end

  defp create_migration_files(%{repo: repo, binary_id: binary_id, users_table: users_table} = config) do
    schema_plural = Map.get(config, :schema_plural, "user_identities")
    context_base  = Pow.context_app() |> Pow.context_base() |> Atom.to_string()
    schema        = UserIdentitiesMigration.new(context_base, schema_plural, repo: repo, binary_id: binary_id, users_table: users_table)
    content       = UserIdentitiesMigration.gen(schema)

    Migration.create_migration_files(repo, schema.migration_name, content)
  end
end
