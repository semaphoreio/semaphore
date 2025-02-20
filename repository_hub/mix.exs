defmodule RepositoryHub.MixProject do
  use Mix.Project

  def project do
    [
      app: :repository_hub,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      elixirc_paths: elixirc_paths(Mix.env()),
      releases: releases()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :tackle],
      mod: {RepositoryHub.Application, []}
    ]
  end

  defp releases do
    [
      repository_hub_service: [
        include_executables_for: [:unix],
        applications: [
          runtime_tools: :permanent,
          repository_hub: :permanent
        ]
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto_sql, "~> 3.0"},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:postgrex, ">= 0.0.0"},
      {:grpc, "0.9.0", github: "elixir-grpc/grpc"},
      {:cowlib, "~> 2.11.0", override: true},
      {:watchman, github: "renderedtext/ex-watchman"},
      {:jason, "~> 1.1"},
      {:httpoison, "~> 1.8"},
      {:util, github: "renderedtext/elixir-util"},
      {:uuid, "~> 1.1"},
      {:mock, "~> 0.3.7", only: [:test]},
      {:junit_formatter, "~> 3.1", only: [:test]},
      {:tentacat, github: "radwo/tentacat", branch: "rw/etag"},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ex_unit_notifier, "~> 1.2", only: :test},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:scrivener_ecto, "~> 2.0"},
      {:excoveralls, "~> 0.10", only: :test},
      {:timex, "~> 3.7.11"},
      {:sentry, "~> 8.0"},
      {:tackle, github: "renderedtext/ex-tackle"},
      {:amqp, "~> 3.0", override: true},
      {:cachex, "~> 3.6"},
      {:broadway_rabbitmq, "~> 0.7"},
      {:tesla, "~> 1.9"},
      {:gun, "~> 2.0.0", override: true},
      {:feature_provider, git: "git@github.com:renderedtext/feature_provider", tag: "v0.2.1"}
    ]
  end

  defp elixirc_paths(env) when env in [:test, :dev], do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
