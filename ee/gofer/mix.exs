# Generated by usvc-1.13.4
# Feel free to adjust, it will not be overridden

defmodule Gofer.Mixfile do
  use Mix.Project

  def project do
    [
      app: :gofer,
      version: "0.2.0",
      elixir: "~> 1.13",
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
      extra_applications: [:logger, :runtime_tools],
      env: [mix_env: Mix.env()],
      mod: {Gofer.Application, []}
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
      {:ecto_sql, "~> 3.8"},
      {:postgrex, "~> 0.13"},
      {:uuid, "~> 1.1"},
      {:wormhole, "~> 2.0"},
      {:scrivener_ecto, "~> 2.7"},
      {:vmstats, "~> 2.4"},
      {:grpc, "~> 0.5.0"},
      {:jason, "~> 1.3"},
      {:cachex, "~> 3.5"},
      {:util, github: "renderedtext/elixir-util"},
      {:when, github: "renderedtext/when"},
      {:watchman, github: "renderedtext/ex-watchman"},
      {:log_tee, git: "https://github.com/renderedtext/log-tee.git"},
      {:tackle, github: "renderedtext/ex-tackle"},
      {:junit_formatter, "~> 3.1", only: [:test]},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:mix_test_watch, "~> 1.1", only: [:dev], runtime: false},
      {:grpc_mock, github: "renderedtext/grpc-mock", only: [:dev, :test]}
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
