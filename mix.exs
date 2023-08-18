defmodule JSONAPIPlug.Mixfile do
  use Mix.Project

  def project do
    [
      app: :jsonapi_plug,
      version: "1.0.3",
      package: package(),
      description: "JSON:API library for Plug and Phoenix applications",
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      source_url: "https://github.com/lucacorti/jsonapi_plug",
      deps: deps(),
      dialyzer: dialyzer(),
      docs: docs()
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
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
      plt_add_deps: :app_tree
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.0", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0", only: :dev, runtime: false},
      {:ex_doc, "~> 0.20", only: :dev, runtime: false},
      {:jason, "~> 1.0"},
      {:nimble_options, "~> 0.4 or ~> 0.5 or ~> 1.0"},
      {:plug, "~> 1.0"}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      groups_for_modules: [
        Document: [~r/JSONAPIPlug\.Document\..*/],
        Plugs: [~r/JSONAPIPlug\.Plug\..*/],
        Ecto: [~r/JSONAPIPlug\.(Normalizer|QueryParser)\.Ecto\.*/],
        Parsers: [~r/JSONAPIPlug\.QueryParser\..*/],
        Behaviours: [~r/JSONAPIPlug\.(Normalizer|Pagination|QueryParser)/]
      ]
    ]
  end

  defp package do
    [
      maintainers: ["Luca Corti"],
      licenses: ["MIT"],
      links: %{
        github: "https://github.com/lucacorti/jsonapi_plug"
      }
    ]
  end
end
