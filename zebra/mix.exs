defmodule Zebra.Mixfile do
  use Mix.Project

  def project do
    [
      app: :zebra,
      version: "0.0.1",
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Zebra.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:grpc, "0.5.0-beta.1", override: true},
      {:protobuf, "~> 0.5.4"},
      {:grpc_mock, github: "renderedtext/grpc-mock", only: [:dev, :test]},
      {:plug_cowboy, "~> 2.3"},
      {:cowboy, "~> 2.9.0", override: true},
      {:cowlib, "~> 2.11.0", override: true},
      {:telemetry, "~> 0.4", override: true},
      {:quantum, "~> 2.3"},
      {:httpoison, "~> 1.0"},
      {:ecto_sql, "~> 3.7.1"},
      {:postgrex, ">= 0.15.13"},
      {:gettext, "~> 0.11"},
      {:timex, "~> 3.6.1"},
      {:amqp_client, "~> 3.9.27"},
      {:tackle, github: "renderedtext/ex-tackle", tag: "v0.2.3"},
      {:mock, "~> 0.3.7", only: :test},
      {:fun_registry, github: "renderedtext/fun-registry", only: [:dev, :test]},
      {:junit_formatter, "~> 3.0", only: [:test]},
      {:paginator, "~> 1.0.0"},
      {:poison, "~> 3.1"},
      {:joken, "~> 2.6"},
      {:watchman, github: "renderedtext/ex-watchman"},
      {:util, github: "renderedtext/elixir-util"},
      {:uuid, "~> 1.1"},
      {:statistics, "~> 0.5.0"},
      {:sentry, "~> 7.0"},
      {:sentry_grpc, github: "renderedtext/sentry_grpc"},
      {:jason, "~> 1.1"},
      {:cachex, "~> 3.2"},
      {:tzdata, "~> 0.5.21"},
      {:yaml_elixir, "~> 2.4"},
      {:mox, "~> 1.0", only: [:dev, :test]},
      {:feature_provider, path: "../feature_provider"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end
end
