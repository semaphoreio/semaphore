defmodule Secrethub.Mixfile do
  use Mix.Project

  def project do
    [
      app: :secrethub,
      version: "0.1.0",
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Secrethub.Application, []}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug, "~> 1.13.6"},
      {:plug_cowboy, "~> 2.5"},
      {:grpc, "0.5.0-beta.1", override: true},
      {:grpc_health_check, github: "renderedtext/grpc_health_check", branch: "protobuf_0.7.1"},
      {:protobuf, "~> 0.7.1"},
      {:cowboy, "~> 2.9.0", override: true},
      {:cowlib, "~> 2.11.0", override: true},
      {:watchman, github: "renderedtext/ex-watchman"},
      {:timex, "~> 3.1"},
      {:cachex, "~> 3.0"},
      {:poison, "~> 5.0"},
      {:httpoison, "~> 1.0", only: [:dev, :test]},
      {:ex_crypto, github: "ntrepid8/ex_crypto"},
      {:postgrex, ">= 0.0.0"},
      {:fun_registry, github: "renderedtext/fun-registry", only: [:dev, :test]},
      {:paginator, "~> 1.1.0"},
      {:sentry, "~> 8.0"},
      {:hackney, "~> 1.8"},
      {:sentry_grpc, github: "renderedtext/sentry_grpc"},
      {:jason, "~> 1.1"},
      {:joken, "~> 2.5"},
      {:junit_formatter, "~> 3.1", only: [:test]},
      {:google_protos, "~> 0.1.0"},
      #### Audit Logs
      {:tackle, github: "renderedtext/ex-tackle"},
      {:amqp, "~> 1.3", override: true},
      {:jsx, "~> 2.9", override: true},
      ### linting
      {:credo, "~> 1.6.5", only: [:dev, :test]},
      {:mock, "~> 0.3.0", only: :test},
      {:feature_provider, git: "git@github.com:renderedtext/feature_provider", tag: "v0.1.0"}
    ]
  end

  defp aliases do
    [
      sentry_recompile: ["compile", "deps.compile sentry --force"]
    ]
  end
end
