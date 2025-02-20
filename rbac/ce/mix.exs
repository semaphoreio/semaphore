defmodule Rbac.MixProject do
  use Mix.Project

  def project do
    [
      app: :rbac,
      version: "0.1.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Rbac.Application, []},
      extra_applications: [:logger, :ssl]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:grpc, "< 0.9.0"},
      {:grpc_mock, github: "renderedtext/grpc-mock", branch: "grpc08", only: [:dev, :test]},
      {:protobuf, "~> 0.13.0"},
      {:mix_test_watch, "~> 1.2.0", only: :dev},
      {:watchman, github: "renderedtext/ex-watchman"},
      {:postgrex, ">= 0.19.2"},
      {:ecto_sql, "~> 3.12.1"},
      {:mock, "~> 0.3.8", only: :test},
      {:jason, "~> 1.4.4"},
      {:junit_formatter, "~> 3.4", only: [:test]},
      {:util, github: "renderedtext/elixir-util"},
      {:mox, "~> 1.2.0", only: [:dev, :test]},
      {:credo, "~> 1.7.10", only: [:dev, :test], runtime: false},
      {:tackle, github: "renderedtext/ex-tackle"},
      {:rabbit_common, "~> 3.13.4", override: true},
      {:cowboy, "~> 2.12.0", override: true},
      {:cowlib, "~> 2.13.0", override: true},
      {:ranch, "~> 1.8.0", override: true}
    ]
  end

  defp elixirc_paths(:prod), do: ["lib"]
  defp elixirc_paths(_), do: ["lib", "test/support"]
end
