defmodule EphemeralEnvironments.MixProject do
  use Mix.Project

  def project do
    [
      app: :ephemeral_environments,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      releases: releases(),
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {EphemeralEnvironments.Application, []}
    ]
  end

  defp releases do
    [
      ephemeral_environments: [
        include_executables_for: [:unix],
        applications: [
          runtime_tools: :permanent,
          ephemeral_environments: :permanent
        ]
      ]
    ]
  end

  defp aliases do
    [
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:credo, "~> 1.5", only: [:dev, :test]},
      {:ecto, "~> 3.12"},
      {:ecto_sql, "~> 3.0"},
      {:postgrex, ">= 0.0.0"},
      {:watchman, github: "renderedtext/ex-watchman"},
      {:excoveralls, "~> 0.18", only: :test},
      {:grpc, "~> 0.6"},
      {:protobuf, "~> 0.11"},
      {:mox, "~> 1.0", only: :test},
      {:junit_formatter, "~> 3.1", only: [:test]}
    ]
  end
end
