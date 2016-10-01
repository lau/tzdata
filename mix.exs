defmodule Tzdata.Mixfile do
  use Mix.Project

  def project do
    [app: :tzdata,
     name: "tzdata",
     version: "0.5.9",
     elixir: "~> 1.0",
     package: package(),
     description: description(),
     deps: deps()]
  end

  def application do
    [
      applications: [:logger, :inets, :ssl],
      env: env(),
      mod: {Tzdata.App, []}
    ]
  end

  defp deps do
    [
      {:earmark, "~> 0.1.17", only: :dev},
      {:ex_doc, "~> 0.10", only: :dev},
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
    %{ licenses: ["MIT"],
       maintainers: ["Lau Taarnskov"],
       links: %{ "GitHub" => "https://github.com/lau/tzdata"},
       files: ~w(lib priv mix.exs README* LICENSE*
                 license* CHANGELOG* changelog* src source_data) }
  end
end
