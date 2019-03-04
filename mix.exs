defmodule Tzdata.Mixfile do
  use Mix.Project

  def project do
    [
      app: :tzdata,
      name: "tzdata",
      version: "1.0.0-rc.0",
      elixir: "~> 1.8",
      package: package(),
      description: description(),
      deps: deps()
    ]
  end

  def application do
    [
      applications: applications(Mix.env()),
      extra_applications: [:logger],
      env: env(),
      mod: {Tzdata.App, []}
    ]
  end

  defp applications(:dev), do: [:hackney]
  defp applications(_), do: []

  defp deps do
    [
      {:hackney, "~> 1.0", optional: true},
      {:ex_doc, "~> 0.18", only: :dev, runtime: false},
    ]
  end

  defp env do
    [
      autoupdate: :enabled,
      data_dir: nil,
      http_client: Tzdata.HTTPClient.Hackney
    ]
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
