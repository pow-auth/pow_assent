defmodule Mix.Tasks.PowAssent.Phoenix.Gen.Templates do
  @shortdoc "Generates PowAssent templates"

  @moduledoc """
  Generates PowAssent templates for Phoenix.

      mix pow_assent.phoenix.gen.templates

      mix pow_assent.phoenix.gen.templates --context-app my_app

  ## Arguments

    * `--context-app` app to use for path and module names
  """
  use Mix.Task

  alias Mix.{Pow, Pow.Phoenix}

  @switches [context_app: :string]
  @default_opts []

  @impl true
  def run(args) do
    Pow.no_umbrella!("pow_assent.phoenix.gen.templates")

    args
    |> Pow.parse_options(@switches, @default_opts)
    |> create_template_files()
  end

  @templates [
    {"registration", ~w(add_user_id)},
  ]

  defp create_template_files({config, _parsed, _invalid}) do
    structure    = Phoenix.parse_structure(config)
    web_module   = structure[:web_module]
    web_prefix   = structure[:web_prefix]

    Enum.each(@templates, fn {name, actions} ->
      Phoenix.create_template_module(Elixir.PowAssent, name, web_module, web_prefix)
      Phoenix.create_templates(Elixir.PowAssent, name, web_prefix, actions)
    end)

    %{structure: structure}
  end
end
