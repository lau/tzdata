defmodule Tzdata.Mixfile do
  use Mix.Project

  @source_url "https://github.com/lau/tzdata"
  @version "1.0.5"

  def project do
    [
      app: :tzdata,
      name: "tzdata",
      version: @version,
      elixir: "~> 1.8",
      package: package(),
      description: description(),
      deps: deps(),
      docs: docs()
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
      {:hackney, "~> 1.0"},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md": [title: "Changelog"]],
      source_url: @source_url,
      source_ref: "v#{@version}"
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
      links: %{
        "Changelog" => @source_url <> "/blob/master/CHANGELOG.md",
        "GitHub" => @source_url
      },
      files: ~w(lib priv mix.exs README* LICENSE* CHANGELOG*)
    }
  end
end
