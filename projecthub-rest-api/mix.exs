defmodule Projecthub.Mixfile do
  use Mix.Project

  def project do
    [
      app: :projecthub,
      version: "0.1.0",
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :sentry],
      mod: {Projecthub.Application, []}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug, "~> 1.7.1"},
      {:plug_cowboy, "~> 2.0"},
      {:grpc, "~> 0.3.1"},
      {:watchman, github: "renderedtext/ex-watchman"},
      {:timex, "~> 3.1"},
      {:cachex, "~> 3.0"},
      {:poison, "~> 3.1"},
      {:httpoison, "~> 0.11", only: [:dev, :test]},
      {:fun_registry, github: "renderedtext/fun-registry", only: [:dev, :test]},
      {:sentry, "~> 7.0"},
      # sentry deps
      {:jason, "~> 1.1"},
      {:junit_formatter, "~> 3.1", only: [:test]},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:uuid, github: "okeuday/uuid", only: [:dev, :test]}
    ]
  end
end
