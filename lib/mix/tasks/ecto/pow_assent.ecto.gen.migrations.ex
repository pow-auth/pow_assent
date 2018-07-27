defmodule Mix.Tasks.PowAssent.Ecto.Gen.Migration do
  @shortdoc "Generates user identities migration file"

  @moduledoc """
  Generates a user identity migrations file.

      mix pow_assent.ecto.gen.migration -r MyApp.Repo
  """
  use Mix.Task

  alias Pow.Ecto.Schema.Migration, as: SchemaMigration
  alias PowAssent.Ecto.UserIdentities.Schema.Migration, as: UserIdentitiesMigration
  alias Mix.{Ecto, Pow, Pow.Ecto.Migration}

  @switches [binary_id: :boolean, users_table: :string]
  @default_opts [binary_id: false, users_table: "users"]

  @doc false
  def run(args) do
    Pow.no_umbrella!("pow_assent.ecto.gen.migration")

    args
    |> Pow.parse_options(@switches, @default_opts)
    |> create_migrations_files(args)
  end

  defp create_migrations_files(config, args) do
    args
    |> Ecto.parse_repo()
    |> Enum.map(&Ecto.ensure_repo(&1, args))
    |> Enum.map(&Map.put(config, :repo, &1))
    |> Enum.each(&create_migration_files/1)
  end

  defp create_migration_files(%{repo: repo, binary_id: binary_id, users_table: users_table}) do
    context_base    = Pow.context_app() |> Pow.context_base() |> Atom.to_string()
    name            = SchemaMigration.name("user_identities")
    content         = UserIdentitiesMigration.gen(context_base, repo: repo, binary_id: binary_id, users_table: users_table)

    Migration.create_migration_files(repo, name, content)
  end
end
