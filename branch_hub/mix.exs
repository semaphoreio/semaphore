defmodule BranchHub.MixProject do
  use Mix.Project

  def project do
    [
      app: :branch_hub,
      version: "0.1.0",
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [
      mod: {BranchHub.Application, []},
      extra_applications: [:logger, :sentry]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:ecto_sql, "~> 3.0"},
      {:scrivener_ecto, "~> 2.0"},
      {:postgrex, ">= 0.0.0"},
      {:protobuf, "0.7.1", override: true},
      {:grpc, "0.5.0-beta.1", override: true},
      {:grpc_health_check, github: "renderedtext/grpc_health_check", branch: "protobuf_0.7.1"},
      {:junit_formatter, "~> 3.3", only: [:test]},
      {:log_tee, github: "renderedtext/log-tee"},
      {:util, github: "renderedtext/elixir-util"},
      {:uuid, "~> 1.1"},
      {:sentry_grpc, github: "renderedtext/sentry_grpc"},
      {:sentry, "~> 8.0"},
      {:jason, "~> 1.1"},
      {:hackney, "~> 1.8"},
      {:credo, "~> 1.7", only: [:dev, :test]}
    ]
  end

  defp aliases do
    [sentry_recompile: ["compile", "deps.compile sentry --force"]]
  end
end
