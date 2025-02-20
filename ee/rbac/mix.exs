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
      {:yaml_elixir, "~> 2.11"},
      {:bypass, "~> 2.1", [only: :test]},
      {:jose, "~> 1.11"},
      {:esaml, git: "https://github.com/dropbox/esaml", tag: "v4.2.0"},
      {:plug_cowboy, "~> 2.0"},
      {:cowboy, "~> 2.12.0", override: true},
      {:cowlib, "~> 2.13.0", override: true},
      {:sentry, "~> 10.8"},
      {:x509, "~> 0.8.10"},
      {:httpoison, "~> 2.2"},
      {:plug_rails_cookie_session_store, "~> 2.0"},
      {:tackle, github: "renderedtext/ex-tackle"},
      {:amqp, "~> 3.3"},
      {:amqp_client, "~> 3.12"},
      {:ex_marshal,
       github: "renderedtext/ex_marshal", ref: "b729808efefb6c61e53b6de13c79c28e2594e97a"},
      {:openid_connect,
       github: "firezone/openid_connect", ref: "dee689382699fce7a6ca70084ccbc8bc351d3246"},
      {:tesla, "1.11.0"},
      {:castore, "0.1.22"},
      {:argon2_elixir, "~> 4.0"},
      {:wormhole, "~> 2.3"},
      {:rabbit_common, "~> 3.13.4", override: true},
      {:ranch, "~> 1.8.0", override: true},
      {:gen_retry, "~> 1.4.0"}
    ]
  end

  defp elixirc_paths(:prod), do: ["lib"]
  defp elixirc_paths(_), do: ["lib", "test/support"]
end
