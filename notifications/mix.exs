defmodule Notifications.Mixfile do
  use Mix.Project

  def project do
    [
      app: :notifications,
      version: "0.1.0",
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [
      mod: {Notifications.Application, []},
      extra_applications: [:logger, :runtime_tools, :sentry]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:grpc, "0.5.0-beta.1", override: true},
      {:cowlib, "~> 2.9", override: true},
      {:amqp, "~> 1.3", override: true},
      {:watchman, github: "renderedtext/ex-watchman"},
      {:timex, "~> 3.1"},
      {:cachex, "~> 3.0"},
      {:poison, "~> 5.0"},
      {:httpoison, "~> 1.4"},
      {:ecto_sql, "~> 3.0"},
      {:postgrex, ">= 0.0.0"},
      {:grpc_mock, github: "renderedtext/grpc-mock", only: [:dev, :test]},
      {:mock, "~> 0.3.0", only: [:dev, :test]},
      {:paginator, "~> 1.0"},
      {:tackle, github: "renderedtext/ex-tackle"},
      {:util, github: "renderedtext/elixir-util", branch: "rw/string_enums"},
      {:sentry, "~> 8.0"},
      {:hackney, "~> 1.8"},
      {:sentry_grpc, github: "renderedtext/sentry_grpc"},
      {:jason, "~> 1.1"},
      {:junit_formatter, "~> 3.3", only: [:test]},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      sentry_recompile: ["compile", "deps.compile sentry --force"]
    ]
  end
end
