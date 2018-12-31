defmodule Tzdata.Mixfile do
  use Mix.Project

  def project do
    [
      app: :tzdata,
      name: "tzdata",
      version: "1.0.0-dev",
      elixir: "~> 1.8 or ~> 1.8.0-dev",
      package: package(),
      description: description(),
      deps: deps()
    ]
  end

  def application do
    [
      applications: [:logger],
      env: env(),
      mod: {Tzdata.App, []}
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.18", only: :dev},
    ]
  end

  defp env do
    [autoupdate: :enabled, data_dir: nil]
  end

  defp description do
    """
    Tzdata is a parser and library for the tz database.
    """
  end

  defp package do
    %{
      licenses: ["MIT"],
      maintainers: ["Lau Taarnskov"],
      links: %{"GitHub" => "https://github.com/lau/tzdata"},
      files: ~w(lib priv mix.exs README* LICENSE*
                 CHANGELOG*)
    }
  end
end
