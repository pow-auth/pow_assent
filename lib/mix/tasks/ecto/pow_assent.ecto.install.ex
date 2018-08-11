defmodule Mix.Tasks.PowAssent.Ecto.Install do
  @shortdoc "Generates user identity schema and migration file"

  @moduledoc """
  Generates user identity schema and migration file.

      mix pow_assent.ecto.install -r MyApp.Repo
  """
  use Mix.Task

  alias Mix.Tasks.PowAssent.Ecto.Gen.Schema, as: SchemaTask
  alias Mix.Tasks.PowAssent.Ecto.Gen.Migration, as: MigrationTask
  alias Mix.Pow

  @switches []
  @default_opts []

  @doc false
  def run(args) do
    Pow.no_umbrella!("pow_assent.ecto.install")

    args
    |> Pow.parse_options(@switches, @default_opts)
    |> run_gen_migration(args)
    |> run_gen_schema(args)
  end

  defp run_gen_migration(config, args) do
    MigrationTask.run(args)

    config
  end

  defp run_gen_schema(config, args) do
    SchemaTask.run(args)

    config
  end
end
