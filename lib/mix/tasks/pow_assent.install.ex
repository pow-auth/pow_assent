defmodule Mix.Tasks.PowAssent.Install do
  @shortdoc "Installs PowAssent"

  @moduledoc """
  Will generate PowAssent migration file.

      mix pow_assent.install -r MyApp.Repo

      mix pow_assent.install -r MyApp.Repo Accounts.Identity identities

  See `Mix.Tasks.PowAssent.Ecto.Install` for more.
  """
  use Mix.Task

  alias Mix.Project
  alias Mix.Tasks.PowAssent.Ecto.Install
  @mix_task "pow_assent.install"

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
      Mix.raise(
        """
        mix #{@mix_task} has to be used inside an application directory, but this is an umbrella project.

        Run mix pow_assent.ecto.install inside your Ecto application directory to create schema module and migrations.
        """)
    end

    :ok
  end
end
