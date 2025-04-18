defmodule Guard.Mixfile do
  use Mix.Project

  def project do
    [
      app: :guard,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [
      mod: {Guard.Application, []},
      extra_applications: [:logger, :sentry, :httpoison, :gen_retry, :ssl]
    ]
  end

  defp elixirc_paths(:prod), do: ["lib"]
  defp elixirc_paths(_), do: ["lib", "test/support"]

  defp deps do
    [
      {:grpc, "0.5.0-beta.1", override: true},
      {:cowboy, "~> 2.9.0", override: true},
      {:cowlib, "~> 2.11.0", override: true},
      {:plug_cowboy, "~> 2.3"},
      {:httpoison, "~> 1.8"},
      {:gen_retry, "~> 1.4.0"},
      {:mix_test_watch, "~> 1.0", only: :dev},
      {:fun_registry, github: "renderedtext/fun-registry", only: [:dev, :test]},
      {:tentacat, "~> 2.0"},
      {:watchman, github: "renderedtext/ex-watchman"},
      {:postgrex, ">= 0.0.0"},
      {:ecto_sql, "~> 3.11.2"},
      {:flop, "~> 0.26.1"},
      {:amqp_client, "~> 3.9.27"},
      {:tackle, github: "renderedtext/ex-tackle", tag: "v0.2.3"},
      {:mock, "~> 0.3.0", only: :test},
      {:grpc_health_check, github: "renderedtext/grpc_health_check"},
      {:sentry, "~> 8.0"},
      {:jason, "~> 1.1"},
      {:exvcr, "~> 0.10", only: :test},
      {:jsx, "~> 3.1", override: true},
      {:cachex, "~> 3.3"},
      {:junit_formatter, "~> 3.1", only: [:test]},
      {:util, github: "renderedtext/elixir-util"},
      {:x509, "~> 0.8.7"},
      {:esaml, git: "https://github.com/dropbox/esaml", tag: "v4.2.0"},
      {:plug_rails_cookie_session_store, "~> 2.0"},
      {:yaml_elixir, "~> 2.9"},
      {:mox, "~> 1.0", only: [:dev, :test]},
      {:feature_provider, path: "../feature_provider"},
      {:ex_marshal,
       github: "renderedtext/ex_marshal", ref: "b729808efefb6c61e53b6de13c79c28e2594e97a"},
      {:unplug, "~> 1.0.0"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:openid_connect,
       github: "firezone/openid_connect", ref: "dee689382699fce7a6ca70084ccbc8bc351d3246"},
      {:bypass, "~> 2.1", only: [:dev, :test]},
      {:remote_ip, "~> 1.1"},
      {:ueberauth_github, "~> 0.8"},
      {:ueberauth_bitbucket,
       git: "https://bitbucket.org/semaphoreci/ueberauth_bitbucket.git",
       ref: "e59638a5671721aa0b5eb02217991a39db993c23"},
      {:ueberauth_gitlab_strategy, "~> 0.4"},
      {:tesla, "~> 1.11.0"},
      {:castore, "~> 0.1.22"},
      {:joken, "~> 2.5"},
      {:hackney, "~> 1.20"},
      {:argon2_elixir, "~> 4.0"},
      {:quantum, "~> 3.0"}
    ]
  end

  defp aliases do
    [sentry_recompile: ["compile", "deps.compile sentry --force"]]
  end
end
