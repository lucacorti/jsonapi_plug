defmodule JSONAPI.Mixfile do
  use Mix.Project

  def project do
    [
      app: :jsonapi,
      version: "1.3.0",
      package: package(),
      description: "JSON:API 1.0 implementation for Plug based projects and applications",
      elixir: "~> 1.9",
      elixirc_paths: elixirc_paths(Mix.env()),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      source_url: "https://github.com/dottori-it/jsonapi",
      deps: deps(),
      dialyzer: dialyzer(),
      docs: [
        extras: [
          "README.md"
        ],
        main: "readme"
      ]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp dialyzer do
    [
      plt_add_deps: :app_tree
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.0", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0", only: :dev, runtime: false},
      {:ex_doc, "~> 0.20", only: :dev, runtime: false},
      {:jason, "~> 1.0"},
      {:plug, "~> 1.0"}
    ]
  end

  defp package do
    [
      maintainers: ["dottori.it"],
      licenses: ["MIT"],
      links: %{
        github: "https://github.com/dottori-it/jsonapi"
      }
    ]
  end
end
