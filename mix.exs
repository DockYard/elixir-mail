defmodule Pdf.Mixfile do
  use Mix.Project

  @version "0.0.1"
  @github_url "https://github.com/andrewtimberlake/elixir-pdf"

  def project do
    [app: :pdf,
     name: "PDF",
     version: @version,
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     source_url: @github_url,
     elixirc_paths: elixirc_paths(Mix.env),
     docs: fn ->
       [source_ref: "v#{@version}",
        canonical: "http://hexdocs.pm/pdf",
        main: "PDF",
        source_url: @github_url,
        extras: ["README.md"]
       ]
     end,
     description: description,
     package: package]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      # Code style
      {:credo, "~> 0.4.8", only: [:dev, :test]},

      # Docs
      {:ex_doc, "~> 0.14.0", only: [:dev, :docs]},
      {:earmark, "~> 1.0.0", only: [:dev, :docs]},
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
     links: %{"GitHub" => @github_url}]
  end
end
