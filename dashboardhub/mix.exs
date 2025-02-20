defmodule Dashboardhub.MixProject do
  use Mix.Project

  def project do
    [
      app: :dashboardhub,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: releases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Dashboardhub.Application, []}
    ]
  end

  defp releases do
    [
      dashboardhub: [
        include_executables_for: [:unix],
        applications: [
          runtime_tools: :permanent,
          dashboardhub: :permanent
        ]
      ]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:grpc, "~> 0.6"},
      {:protobuf, "~> 0.11"},
      {:fun_registry, github: "renderedtext/fun-registry", only: [:dev, :test]},
      {:ecto_sql, "~> 3.0"},
      {:postgrex, ">= 0.0.0"},
      {:poison, "~> 3.1"},
      {:watchman, github: "renderedtext/ex-watchman"},
      {:tackle, github: "renderedtext/ex-tackle"},
      {:amqp, "~> 3.0", override: true},
      {:paginator, "~> 1.0"},
      {:junit_formatter, "~> 3.1", only: [:test]},
      {:jason, "~> 1.2"},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:sentry, "~> 8.0"},
      {:sentry_grpc, github: "renderedtext/sentry_grpc"},
      {:hackney, "~> 1.8"}
    ]
  end
end
