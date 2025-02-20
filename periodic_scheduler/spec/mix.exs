defmodule Spec.Mixfile do
  use Mix.Project

  def project do
    [app: :spec,
     version: "0.0.1",
     elixir: "~> 1.14",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [extra_applications: [:logger],
     mod: {Spec.Application, []}]
  end

  defp deps do
    [
      {:yaml_elixir, "~> 2.9"},
      # {:jesse, "~> 1.4.0"},
      {:ex_json_schema, "~> 0.9"},
    ]
  end
end
