defmodule Auth.Mixfile do
  use Mix.Project

  def project do
    [
      app: :auth,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Auth.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug, "~> 1.14"},
      {:remote_ip, "~> 1.1"},
      {:grpc, "~> 0.9"},
      {:protobuf, "~> 0.14", override: true},
      {:cowboy, "~> 2.10", override: true},
      {:cowlib, "~> 2.12", override: true},
      {:fun_registry, github: "renderedtext/fun-registry", only: [:dev, :test]},
      {:watchman, github: "renderedtext/ex-watchman"},
      {:feature_provider, path: "../feature_provider"},
      {:yaml_elixir, ">= 2.0.0"},
      {:cachex, "~> 3.0"},
      {:httpoison, "~> 0.11", only: [:dev, :test]},
      {:sentry, "~> 8.0"},
      {:hackney, "~> 1.20"},
      {:plug_cowboy, "~> 2.7"},
      {:jason, "~> 1.4"},
      {:inet_cidr, "~> 1.0.0"},
      {:wormhole, "~> 2.3"},
      {:credo, "~> 1.7.10", only: [:dev, :test], runtime: false},
      {:junit_formatter, "~> 3.1", only: [:test]},
      {:uuid, "~> 1.1"},
      # MCP OAuth 2.1 JWT validation (HS256)
      {:joken, "~> 2.6"}
    ]
  end
end
