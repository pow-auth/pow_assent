defmodule Mix.Tasks.PowAssent.Ecto.Install do
  @shortdoc "Generates user identity schema and migration file"

  @moduledoc """
  Generates user identity schema and migration file.

      mix pow_assent.ecto.install -r MyApp.Repo

      mix pow_assent.ecto.install -r MyApp.Repo Accounts.Identity identities

  See `Mix.Tasks.PowAssent.Ecto.Gen.Schema` and
  `Mix.Tasks.PowAssent.Ecto.Gen.Migration` for more.
  """
  use Mix.Task

  alias Mix.Tasks.PowAssent.Ecto.Gen.Migration, as: MigrationTask
  alias Mix.Tasks.PowAssent.Ecto.Gen.Schema, as: SchemaTask
  alias Mix.{Pow, PowAssent}

  @switches []
  @default_opts []
  @mix_task "pow_assent.ecto.install"

  @impl true
  def run(args) do
    Pow.no_umbrella!(@mix_task)

    args
    |> Pow.parse_options(@switches, @default_opts)
    |> parse()
    |> run_gen_migration(args)
    |> run_gen_schema(args)
  end

  defp parse({config, parsed, _invalid}) do
    PowAssent.validate_schema_args!(parsed, @mix_task)

    config
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
