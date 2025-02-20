defmodule Spec.Mixfile do
  use Mix.Project

  def project do
    [
      app: :spec,
      version: "0.0.1",
      elixir: "~> 1.11",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :runtime_tools],
      env: [mix_env: Mix.env()],
      mod: {Spec.Application, []}
    ]
  end

  defp deps do
    [
      {:yaml_elixir, "~> 1.3.1"},
      {:jesse, "~> 1.4.0"},
      {:ex_json_schema, "~> 0.8.1"},
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false},
      {:junit_formatter, "~> 3.1", only: [:dev, :test]}
    ]
  end

  defp aliases() do
    [
      "deps.local": ["local.hex --force", "local.rebar --force"],
      "deps.setup": ["deps.local", "deps.get"],
      setup: ["deps.setup"]
    ]
  end
end
