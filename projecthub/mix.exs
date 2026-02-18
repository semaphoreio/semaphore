defmodule Projecthub.MixProject do
  use Mix.Project

  def project do
    [
      app: :projecthub,
      version: "0.1.0",
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      releases: releases()
    ]
  end

  def application do
    [
      mod: {Projecthub.Application, []},
      extra_applications: [:logger, :tackle, :sentry]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:ecto_sql, "~> 3.0"},
      {:scrivener_ecto, "~> 2.0"},
      {:paginator, "~> 1.1.0"},
      {:postgrex, ">= 0.0.0"},
      {:grpc, "~> 0.5.0"},
      {:protobuf, "~> 0.11"},
      {:tackle, github: "renderedtext/ex-tackle"},
      {:amqp, "~> 1.3", override: true},
      {:jsx, "~> 3.1", override: true},
      {:timex, "~> 3.3"},
      {:tentacat, "~> 2.0"},
      {:poison, "~> 5.0"},
      {:watchman, github: "renderedtext/ex-watchman"},
      {:sentry, "~> 8.0"},
      {:sentry_grpc, github: "renderedtext/sentry_grpc"},
      {:jason, "~> 1.1"},
      {:mock, "~> 0.3.0", only: :test},
      {:fun_registry, github: "renderedtext/fun-registry", only: [:dev, :test]},
      {:exvcr, "~> 0.10", only: :test},
      {:junit_formatter, "~> 3.3", only: [:test]},
      {:credo, "~> 1.6.1", only: [:dev, :test]},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false},
      {:feature_provider, path: "../feature_provider"},
      {:yaml_elixir, ">= 2.0.0"},
      {:ymlr, "~> 5.0"},
      {:cachex, ">= 3.0.0"},
      {:quantum, "~> 3.0"}
    ]
  end

  defp aliases do
    [sentry_recompile: ["compile", "deps.compile sentry --force"]]
  end

  defp releases do
    [
      projecthub: [
        include_executables_for: [:unix]
      ]
    ]
  end
end
