defmodule Nuntiux.MixProject do
  use Mix.Project

  @version "1.0.0"
  @elixir "~> 1.12"

  @github "https://github.com/2Latinos/nuntiux"

  def project do
    [
      aliases: aliases(),
      app: :nuntiux,
      deps: deps(),
      description: "A library to mock registered processes",
      dialyzer: dialyzer(),
      docs: docs(),
      elixir: @elixir,
      elixirc_options: elixirc_options(),
      name: "Nuntiux",
      package: package(),
      preferred_cli_env: [ci: :test],
      source_url: @github,
      version: @version
    ]
  end

  def application do
    start_args = []

    [
      extra_applications: [:logger],
      mod: {Nuntiux.Application, start_args}
    ]
  end

  defp aliases do
    [
      ci: [
        "docs",
        "format",
        "credo",
        "dialyzer",
        "test --cover"
      ]
    ]
  end

  defp deps do
    [
      {:credo, "1.7.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "1.3.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "0.29.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp dialyzer do
    [
      flags: [
        :error_handling,
        :underspecs,
        :unknown,
        :unmatched_returns
      ],
      plt_add_deps: :apps_direct
    ]
  end

  defp docs do
    [
      extras: [
        "README.md",
        "SECURITY.md",
        "CODE_OF_CONDUCT.md",
        "CONTRIBUTING.md",
        "LICENSE.md",
        "CHANGELOG.md"
      ],
      main: "readme"
    ]
  end

  defp elixirc_options do
    [
      warnings_as_errors: true
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{GitHub: @github},
      maintainers: ["2Latinos"]
    ]
  end
end
