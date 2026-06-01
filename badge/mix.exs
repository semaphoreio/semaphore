defmodule Badges.MixProject do
  use Mix.Project

  def project do
    [
      app: :badges,
      version: "0.0.1",
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Badges.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug, "~> 1.15.4"},
      {:plug_cowboy, "~> 2.8.1"},
      {:cowboy, "~> 2.15.0", override: true},
      {:cowlib, "~> 2.16.1", override: true},
      {:grpc, "0.5.0-beta.1", override: true},
      {:protobuf, "~> 0.6.3", override: true},
      {:grpc_mock, github: "renderedtext/grpc-mock", only: [:dev, :test]},
      {:watchman, github: "renderedtext/ex-watchman"},
      {:cachex, "~> 3.2"},
      {:sentry, "~> 7.0"},
      {:hackney, "~> 1.24", override: true},
      {:jason, "~> 1.1"},
      {:mix_audit, "~> 0.1", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.8", only: :dev},
      {:junit_formatter, "~> 3.1", only: [:test]},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end
end
