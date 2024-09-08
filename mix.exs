defmodule Tzdata.Mixfile do
  use Mix.Project

  def project do
    [
      app: :tzdata,
      name: "tzdata",
      version: version(),
      elixir: "~> 1.8",
      package: package(),
      description: description(),
      deps: deps(),
      docs: docs(),
      source_url: "https://github.com/lau/tzdata"
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      env: env(),
      mod: {Tzdata.App, []}
    ]
  end

  defp deps do
    [
      {:hackney, "~> 1.17"},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:mox, "~> 1.2", only: :test}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_ref: "v#{version()}"
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
      files: ~w(lib priv mix.exs README* LICENSE* VERSION
                 CHANGELOG*)
    }
  end

  defp version do
    "./VERSION"
    |> File.read!()
    |> String.trim()
  end
end
