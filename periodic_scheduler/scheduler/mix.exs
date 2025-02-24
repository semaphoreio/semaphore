defmodule Scheduler.Mixfile do
  use Mix.Project

  def project do
    [
      app: :scheduler,
      version: "0.3.0",
      elixir: "~> 1.14",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      aliases: aliases()
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [
      extra_applications: [:lager, :logger, :runtime_tools],
      env: [mix_env: Mix.env()],
      mod: {Scheduler.Application, []}
    ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      # regular dependencies
      {:postgrex, "~> 0.17"},
      {:ecto_sql, "~> 3.10"},
      {:scrivener_ecto, "~> 2.7"},
      {:paginator, "~> 1.2"},
      {:uuid, "~> 1.1"},
      {:jason, "~> 1.1"},
      {:grpc, "~> 0.5"},
      {:quantum, "~> 3.5"},
      {:timex, "~> 3.7"},
      {:vmstats, "~> 2.4"},
      {:cachex, "~> 3.6"},
      {:amqp, "~> 1.6", override: true},
      # internal dependencies
      {:definition_validator, path: "../definition_validator"},
      # renderedtext dependencies
      {:util, github: "renderedtext/elixir-util"},
      {:watchman, github: "renderedtext/ex-watchman"},
      {:log_tee, github: "renderedtext/log-tee"},
      {:tackle, github: "renderedtext/ex-tackle"},
      {:feature_provider, path: "../../feature_provider"},
      # development dependencies
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:junit_formatter, "~> 3.1", only: [:test]}
    ]
  end

  defp aliases() do
    [
      "deps.local": ["local.hex --force", "local.rebar --force"],
      "deps.setup": ["deps.local", "deps.get"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      setup: ["deps.setup", "ecto.setup"]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
