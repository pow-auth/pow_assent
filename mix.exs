defmodule PowAssent.MixProject do
  use Mix.Project

  @version "0.4.5"

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
      {:pow, "~> 1.0.16"},
      {:assent, "~> 0.1.2"},

      {:ecto, "~> 2.2 or ~> 3.0"},
      {:phoenix, "~> 1.3.0 or ~> 1.4.0"},
      {:phoenix_html, ">= 2.0.0 and <= 3.0.0"},
      {:plug, ">= 1.5.0 and < 2.0.0", optional: true},

      {:phoenix_ecto, "~> 4.0.0", only: [:dev, :test]},
      {:credo, "~> 1.1.0", only: [:dev, :test]},
      {:jason, "~> 1.0", only: [:dev, :test]},

      {:ex_doc, "~> 0.21.0", only: :dev},

      {:ecto_sql, "~> 3.1", only: :test},
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
      links: %{github: "https://github.com/pow-auth/pow_assent"},
      files: ~w(lib LICENSE mix.exs README.md)
    ]
  end

  defp docs do
    [
      markdown_processor: ExDoc.PowAssent.Markdown,
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
      ],
      groups_for_modules: [
        Ecto: ~r/^PowAssent.Ecto/,
        Phoenix: ~r/^PowAssent.Phoenix/
      ]
    ]
  end
end
