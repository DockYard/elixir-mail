defmodule Mail.Mixfile do
  use Mix.Project

  @source_url "https://github.com/DockYard/elixir-mail"
  @version "0.2.3"

  def project do
    [
      app: :mail,
      version: @version,
      elixir: "~> 1.3",
      elixirc_paths: elixirc_paths(Mix.env()),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      docs: docs(),
      deps: deps()
    ]
  end

  def application do
    [applications: [:crypto, :logger]]
  end

  def package do
    [
      maintainers: ["Brian Cardarella", "Andrew Timberlake"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Built by DockYard, Expert Elixir & Phoenix Consultants" =>
          "https://dockyard.com/phoenix-consulting"
      }
    ]
  end

  defp docs do
    [
      extras: ["CHANGELOG.md", "README.md"],
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}"
    ]
  end

  def description do
    "Easily build a composable mail message"
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end
end
