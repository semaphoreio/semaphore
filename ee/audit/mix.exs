defmodule Audit.MixProject do
  use Mix.Project

  def project do
    [
      app: :audit,
      version: "0.1.0",
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      releases: releases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :sentry, :ssl],
      mod: {Audit.Application, []}
    ]
  end

  #
  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:grpc, "0.5.0-beta.1", override: true},
      {:cowlib, "~> 2.11.0", override: true},
      {:amqp, "~> 1.3", override: true},
      {:grpc_mock, github: "renderedtext/grpc-mock", only: [:dev, :test]},
      {:protobuf, "~> 0.7.1"},
      {:ecto_sql, "~> 3.0"},
      {:postgrex, ">= 0.0.0"},
      {:tackle, github: "renderedtext/ex-tackle"},
      {:poison, "~> 3.1"},
      {:watchman, github: "renderedtext/ex-watchman"},
      {:jason, "~> 1.1"},
      {:sentry, "~> 8.0"},
      {:hackney, "~> 1.8"},
      {:sentry_grpc, github: "renderedtext/sentry_grpc"},
      {:util, github: "renderedtext/elixir-util"},
      {:grpc_health_check, github: "renderedtext/grpc_health_check", branch: "protobuf_0.7.1"},
      # used for feature flags
      {:uuid, "~> 1.1"},
      # used for feature flags
      {:yaml_elixir, "~> 2.4"},
      {:paginator, "~> 1.1.0"},
      # used for audit streaming
      {:ex_aws, "~> 2.1"},
      {:ex_aws_s3, "~> 2.0"},
      {:sweet_xml, "~> 0.6"},
      {:csv, "~> 2.3"},
      {:timex, "~> 3.0"},
      {:cachex, "~> 3.2"},
      {:feature_provider, path: "../../feature_provider"},
      {:inet_cidr, "~> 1.0.0"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:junit_formatter, "~> 3.1", only: [:test]}
    ]
  end

  defp aliases do
    [
      sentry_recompile: ["compile", "deps.compile sentry --force"]
    ]
  end

  defp releases do
    [
      audit: [
        include_executables_for: [:unix]
      ]
    ]
  end
end
