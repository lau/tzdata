defmodule Tzdata.Mixfile do
  use Mix.Project

  @version "1.1.1"

  def project do
    [
      app: :tzdata,
      name: "tzdata",
      version: @version,
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
      extra_applications: [:logger, :inets, :public_key],
      env: env(),
      mod: {Tzdata.App, []}
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:castore, "~> 0.1.17"}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_ref: "v#{@version}"
    ]
  end

  defp env do
    [
      autoupdate: :enabled,
      data_dir: nil,
      http_client: Tzdata.HTTPClient.Httpc
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
