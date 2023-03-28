defmodule PowAssent.MixProject do
  use Mix.Project

  @version "0.4.17"

  def project do
    [
      app: :pow_assent,
      version: @version,
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      compilers: Mix.compilers(),
      deps: deps(),

      # Hex
      description: "Multi-provider support for Pow",
      package: package(),

      # Docs
      name: "PowAssent",
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :ssl, :inets]
    ]
  end

  defp deps do
    [
      {:pow, "~> 1.0.29"},
      {:assent, "~> 0.1.2 or ~> 0.2.0"},

      {:ecto, "~> 2.2 or ~> 3.0"},
      {:phoenix, ">= 1.3.0 and < 1.8.0"},
      {:phoenix_html, ">= 2.0.0 and <= 4.0.0"},
      {:plug, ">= 1.5.0 and < 2.0.0", optional: true},
      {:phoenix_live_view, ">= 0.18.0", optional: true},

      {:phoenix_ecto, "~> 4.0", only: [:dev, :test]},
      {:credo, "~> 1.1", only: [:dev, :test]},
      {:jason, "~> 1.0", only: [:dev, :test]},

      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},

      {:ecto_sql, "~> 3.1", only: :test},
      {:postgrex, "~> 0.14", only: :test},
      {:floki, ">= 0.30.0", only: :test},
      {:ssl_verify_fun, "~> 1.1", only: :test},
      {:test_server, "~> 0.1.0", only: :test}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      maintainers: ["Dan Schultzer"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/pow-auth/pow_assent",
        "Sponsor" => "https://github.com/sponsors/danschultzer"
      },
      files: ~w(lib LICENSE mix.exs README.md)
    ]
  end

  defp docs do
    [
      source_ref: "v#{@version}",
      main: "README",
      canonical: "http://hexdocs.pm/pow_assent",
      source_url: "https://github.com/pow-auth/pow_assent",
      logo: "assets/logo.svg",
      assets: "assets",
      extras: [
        "README.md": [filename: "README"],
        "CHANGELOG.md": [filename: "CHANGELOG"],
        "guides/set_up_pow.md": [],
        "guides/capture_access_token.md": [],
        "guides/legacy_migration.md": [],
        "guides/api.md": [],
        "guides/dynamic_strategy_configuration.md": []
      ],
      groups_for_modules: [
        Ecto: ~r/^PowAssent.Ecto/,
        Phoenix: ~r/^PowAssent.Phoenix/
      ]
    ]
  end
end
