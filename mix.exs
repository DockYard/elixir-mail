defmodule Mail.Mixfile do
  use Mix.Project

  def project do
    [
      app: :mail,
      version: "0.2.1",
      elixir: "~> 1.2",
      elixirc_paths: elixirc_paths(Mix.env()),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      docs: [main: "Mail"],
      deps: deps()
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger]]
  end

  def package do
    [
      maintainers: ["Brian Cardarella"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/DockYard/elixir-mail",
        "Built by DockYard, Expert Elixir & Phoenix Consultants" =>
          "https://dockyard.com/phoenix-consulting"
      }
    ]
  end

  def description do
    "Easily build a composable mail message"
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

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
      {:earmark, "~> 1.3", only: :dev},
      {:ex_doc, "~> 0.19", only: :dev}
    ]
  end
end
