defmodule Tzdata.Mixfile do
  use Mix.Project

  @version "1.2.2"

  def project do
    [
      app: :tzdata,
      name: "tzdata",
      version: @version,
      elixir: "~> 1.12",
      package: package(),
      description: description(),
      deps: deps(),
      docs: docs(),
      source_url: "https://github.com/lau/tzdata"
    ]
  end

  def application do
    [
      extra_applications: [:logger, :inets, :ssl],
      env: env(),
      mod: {Tzdata.App, []}
    ]
  end

  defp deps do
    [
      {:hackney, "~> 1.17 or ~> 4.0", optional: true},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false}
    ] ++ test_only_deps()
  end

  # Sham and its Bandit adapter require PartitionSupervisor (Elixir 1.13+),
  # which doesn't exist on the oldest Elixir version this library supports.
  # Only pull them in when they're actually usable.
  defp test_only_deps do
    if Version.match?(System.version(), ">= 1.13.0") do
      [
        {:sham, "~> 1.2", only: :test},
        {:bandit, "~> 1.0", only: :test}
      ]
    else
      []
    end
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
      data_dir: nil
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
