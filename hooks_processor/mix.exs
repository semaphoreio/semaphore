defmodule HooksProcessor.MixProject do
  use Mix.Project

  def project do
    [
      app: :hooks_processor,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger, :tackle],
      mod: {HooksProcessor.Application, []}
    ]
  end

  defp deps do
    [
      {:plug_cowboy, "~> 2.0"},
      {:httpoison, "~> 2.0"},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:log_tee, github: "renderedtext/log-tee"},
      {:amqp_client, "~> 3.11.18"},
      {:tackle, github: "renderedtext/ex-tackle", tag: "v0.3.0"},
      {:util, github: "renderedtext/elixir-util"},
      {:watchman, github: "renderedtext/ex-watchman", tag: "v0.3.0", override: true},
      {:grpc_mock, github: "renderedtext/grpc-mock", branch: "grpc08", only: [:dev, :test]},
      {:grpc, "~> 0.9.0"},
      {:protobuf, "~> 0.13.0"},
      {:ecto_sql, "~> 3.0"},
      {:postgrex, ">= 0.0.0"},
      {:uuid, "~> 1.1"},
      {:logger_json, "~> 7.0"},
      {:jason, "~> 1.4"},
      {:junit_formatter, "~> 3.1", only: [:test]},
      # head because support for JSON is not yet released
      {:sentry, github: "getsentry/sentry-elixir", ref: "f375551f32f35674f9baab470d0e571466b07055"},
      {:sentry_grpc, github: "radwo/sentry_grpc", branch: "grpc08"}
    ]
  end
end
