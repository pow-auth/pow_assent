defmodule Mix.Tasks.PowAssent.Install do
  @shortdoc "Installs PowAssent"

  @moduledoc """
  Will generate PowAssent migration file.

      mix pow_assent.install -r MyApp.Repo
  """
  use Mix.Task

  alias Mix.Pow
  alias Mix.Tasks.PowAssent.Ecto.Install

  @switches []
  @default_opts []

  @doc false
  def run(args) do
    Pow.no_umbrella!("pow_assent.install")

    args
    |> Pow.parse_options(@switches, @default_opts)
    |> run_ecto_install(args)
  end

  defp run_ecto_install(config, args) do
    Install.run(args)

    config
  end
end
