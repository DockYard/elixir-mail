defmodule Pdf.Mixfile do
  use Mix.Project

  @version "0.4.0"
  @github_url "https://github.com/andrewtimberlake/elixir-pdf"

  def project do
    [
      app: :pdf,
      name: "PDF",
      version: @version,
      elixir: "~> 1.3",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      source_url: @github_url,
      elixirc_paths: elixirc_paths(Mix.env()),
      docs: fn ->
        [
          source_ref: "v#{@version}",
          canonical: "http://hexdocs.pm/pdf",
          main: "Pdf",
          source_url: @github_url,
          extras: ["extra_doc/Tables.md"],
          assets: "extra_doc/assets",
          formatters: ["html"]
        ]
      end,
      description: description(),
      package: package()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [applications: [:logger]]
  end

  defp deps do
    [
      # Code style
      {:credo, "~> 1.0", only: [:dev, :test]},

      # Docs
      {:ex_doc, "~> 0.0", only: [:dev, :docs]},
      {:earmark, "~> 1.0", only: [:dev, :docs]}
    ]
  end

  defp description do
    """
    Elixir API for generating PDF documents.
    """
  end

  defp package do
    [
      maintainers: ["Andrew Timberlake"],
      contributors: ["Andrew Timberlake"],
      licenses: ["MIT"],
      links: %{"GitHub" => @github_url},
      # files: ~w(lib priv mix.exs README* readme* LICENSE* license* CHANGELOG* changelog* fonts)
      files: ~w(lib mix.exs README* fonts)
    ]
  end
end
