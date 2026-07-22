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
      {:grpc, "~> 0.9.0"},
      {:grpc_mock, github: "renderedtext/grpc-mock", branch: "grpc08", only: [:dev, :test]},
      {:watchman, github: "renderedtext/ex-watchman"},
      {:tackle, github: "renderedtext/ex-tackle", tag: "v0.3.0"},
      {:amqp, "~> 4.1", override: true},
      {:sentry, "~> 8.0"},
      {:tentacat, "~> 2.0"},
      {:cachex, "~> 3.0"},
      {:poison, "~> 3.1"},
      {:protobuf, "~> 0.13.0"},
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
