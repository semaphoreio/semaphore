defmodule HooksReceiver.MixProject do
  use Mix.Project

  def project do
    [
      app: :hooks_receiver,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :amqp],
      mod: {HooksReceiver.Application, []}
    ]
  end

  defp deps do
    [
      {:util, github: "renderedtext/elixir-util"},
      {:plug_cowboy, "~> 2.0"},
      {:amqp_client, "~> 3.11.18"},
      {:tackle, github: "renderedtext/ex-tackle", tag: "v0.3.0"},
      {:grpc, "~> 0.9.0"},
      {:protobuf, "~> 0.13.0"},
      {:grpc_mock, github: "renderedtext/grpc-mock", branch: "grpc08", only: [:dev, :test]},
      {:httpoison, "~> 2.0", only: :test},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:mock, "~> 0.3.0", only: :test},
      {:junit_formatter, "~> 3.1", only: [:test]}
    ]
  end
end
