defmodule PowAssent.MixProject do
  use Mix.Project

  @version "0.1.0-rc.1"

  def project do
    [
      app: :pow_assent,
      version: @version,
      elixir: "~> 1.6",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      compilers: [:phoenix] ++ Mix.compilers(),
      deps: deps(),

      # Hex
      description: "Multi-provider support for Pow",
      package: package(),

      # Docs
      name: "PowAssent",
      docs: docs(),

      dialyzer: [
        ignore_warnings: ".dialyzer_ignore",
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:pow, "~> 1.0.0"},

      {:oauther, "~> 1.1"},
      {:certifi, ">= 0.0.0", optional: true},
      {:ssl_verify_fun, ">= 0.0.0", optional: true},

      {:phoenix_html, ">= 2.0.0 and <= 3.0.0"},
      {:phoenix_ecto, ">= 3.0.0 and <= 4.0.0"},

      {:ecto, "~> 2.2 or ~> 3.0"},
      {:phoenix, "~> 1.3.0 or ~> 1.4.0"},
      {:plug, ">= 1.5.0 and < 1.8.0", optional: true},

      {:credo, "~> 0.10.2", only: [:dev, :test]},
      {:jason, "~> 1.0", only: [:dev, :test]},

      {:ex_doc, "~> 0.19.0", only: :dev},

      {:ecto_sql, "~> 3.0.0", only: :test},
      {:postgrex, "~> 0.14.0", only: :test},
      {:bypass, "~> 1.0.0", only: :test}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      maintainers: ["Dan Shultzer"],
      licenses: ["MIT"],
      links: %{github: "https://github.com/danschultzer/pow_assent"},
      files: ~w(lib LICENSE mix.exs README.md)
    ]
  end

  defp docs do
    [
      source_ref: "v#{@version}",
      main: "PowAssent",
      canonical: "http://hexdocs.pm/pow_assent",
      source_url: "https://github.com/danschultzer/pow_assnet",
      extras: [
        "README.md": [filename: "PowAssent", title: "PowAssent"]
      ],
      groups_for_modules: [
        Ecto: ~r/^PowAssent.Ecto/,
        Phoenix: ~r/^PowAssent.Phoenix/,
        Strategies: ~r/^PowAssent.Strategy/
      ]
    ]
  end
end
