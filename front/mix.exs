defmodule Front.Mixfile do
  use Mix.Project

  def project do
    [
      app: :front,
      version: "0.0.1",
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      xref: [exclude: [IEx.Pry, IEx]],
      aliases: aliases(),
      releases: releases()
    ]
  end

  def application do
    [
      mod: {Front.Application, []},
      extra_applications: [:logger, :runtime_tools, :sentry]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:plug_cowboy, "~> 2.5"},
      {:phoenix, "~> 1.6.0", override: true},
      {:phoenix_html, "~> 3.0.0", override: true},
      {:phoenix_ecto, "~> 4.0"},
      {:phoenix_live_reload, "~> 1.3", only: :dev},
      {:poison, "~> 6.0", override: true},
      {:gettext, "~> 0.11"},
      {:grpc, "0.5.0-beta.1", override: true},
      {:cowboy, "~> 2.9.0", override: true},
      {:cowlib, "~> 2.11.0", override: true},
      {:watchman, github: "renderedtext/ex-watchman"},
      {:traceman, github: "renderedtext/traceman"},
      {:cacheman, github: "renderedtext/ex-cacheman"},
      {:timex, "~> 3.1"},
      {:sentry, "~> 8.0"},
      {:jason, "~> 1.1"},
      {:cachex, "~> 3.4"},
      {:tentacat, github: "renderedtext/tentacat"},
      {:httpoison, ">= 0.0.0"},
      {:uuid, "~> 1.1"},
      {:wallaby, "~> 0.23.0", runtime: false, only: [:dev, :test]},
      {:fun_registry, github: "renderedtext/fun-registry", only: [:dev, :test]},
      {:grpc_mock, github: "renderedtext/grpc-mock", only: [:dev, :test]},
      {:yaml_elixir, "~> 2.4"},
      {:junit_formatter, "~> 3.3", only: [:test]},
      {:mock, "~> 0.3.8", only: :test},
      {:mox, "~> 1.0", only: :test},
      {:util, github: "renderedtext/elixir-util"},
      {:typed_struct, "~> 0.1.4"},
      {:amqp_client, "~> 3.9.27"},
      {:tackle, github: "renderedtext/ex-tackle", tag: "v0.2.3"},
      {:jsx, "~> 2.9", override: true},
      {:csv, "~> 2.3"},
      {:crontab, "~> 1.1.10"},
      {:mix_audit, "~> 0.1", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.8", only: :dev},
      {:plug_content_security_policy, "~> 0.2.1"},
      {:faker, "~> 0.17", only: [:dev, :test]},
      {:joken, "~> 2.4"},
      {:excoveralls, "~> 0.10", only: :test},
      {:stream_data, "~> 0.5", only: [:dev, :test]},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:feature_provider, path: "../feature_provider"},
      # since ex_crypto's maintainer didn't release the version for OTP 24, we're using the git ref
      {:ex_crypto, github: "ntrepid8/ex_crypto", ref: "0997a1aaebe701523c0a9b71d4acec4a1819354e"},
      {:money, "~> 1.12.4"},
      {:quantum, "~> 3.0"}
    ]
  end

  defp aliases do
    [
      sentry_recompile: ["compile", "deps.compile sentry --force"],
      "assets.deploy": ["cmd --cd assets MIX_ENV=prod node build.js", "phx.digest"]
    ]
  end

  defp releases do
    [
      front: [
        include_executables_for: [:unix]
      ]
    ]
  end
end
