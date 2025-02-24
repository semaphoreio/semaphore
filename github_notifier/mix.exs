defmodule GithubNotifier.MixProject do
  use Mix.Project

  def project do
    [
      app: :github_notifier,
      version: "0.2.0",
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :runtime_tools],
      mod: {GithubNotifier.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:grpc, github: "elixir-grpc/grpc", override: true},
      # 2.9.0 fixes some important bugs, so it's better to use ~> 2.9.0
      {:cowlib, "~> 2.9.0", override: true},
      {:grpc_mock, github: "renderedtext/grpc-mock", only: [:dev, :test]},
      {:watchman, github: "renderedtext/ex-watchman"},
      {:tackle, github: "renderedtext/ex-tackle"},
      {:sentry, "~> 8.0"},
      {:tentacat, "~> 2.0"},
      {:cachex, "~> 3.0"},
      {:poison, "~> 3.1"},
      {:protobuf, "~> 0.5.4"},
      {:feature_provider, path: "../feature_provider"},
      {:junit_formatter, "~> 3.3", only: [:test]},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      sentry_recompile: ["compile", "deps.compile sentry --force"]
    ]
  end
end
