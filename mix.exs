defmodule Arc.Storage.Manta.Mixfile do
  use Mix.Project

  @version "0.0.1"

  def project do
    [app: :arc_manta,
     version: @version,
     elixir: "~> 1.0",
     deps: deps,

     # Hex
     description: description,
     package: package]
  end

  defp description do
    """
    Provides Joyent Manta storage backend for Arc.
    """
  end

  defp package do
    [maintainers: ["Dan Connor"],
     licenses: ["Apache 2.0"],
     links: %{"GitHub" => "https://github.com/onyxrev/arc_manta"},
     files: ~w(mix.exs README.md lib)]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    [
      {:arc,       "~> 0.5.3"},
      {:poison,    "~> 1.2 or ~> 2.0" },
      {:calendar,  "~> 0.14.2"},
      {:httpoison, "~> 0.7" },
      {:mock,      "~> 0.1.1", only: :test},
      {:ex_doc,    ">= 0.0.0", only: :dev}
    ]
  end
end
