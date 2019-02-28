defmodule Mix.Tasks.PowAssent.Install do
  @shortdoc "Installs PowAssent"

  @moduledoc """
  Will generate PowAssent migration file.

      mix pow_assent.install -r MyApp.Repo
  """
  use Mix.Task

  alias Mix.Project
  alias Mix.Tasks.PowAssent.Ecto.Install

  @doc false
  def run(args) do
    no_umbrella!()

    run_ecto_install(args)
  end

  defp run_ecto_install(args) do
    Install.run(args)
  end

  defp no_umbrella! do
    if Project.umbrella?() do
      Mix.raise("mix pow_assent.install can't be used in umbrella apps. Run mix pow_assent.ecto.install in your ecto app directory.")
    end

    :ok
  end
end
