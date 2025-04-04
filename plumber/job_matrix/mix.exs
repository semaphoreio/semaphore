# Generated by usvc-1.13.4
# Feel free to adjust, it will not be overridden

defmodule JobMatrix.Mixfile do
  use Mix.Project

  def project do
    [
      app: :job_matrix,
      version: "0.2.0",
      elixir: "~> 1.11",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [
      extra_applications: [:logger, :runtime_tools],
      env: [mix_env: Mix.env()]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false},
      {:util, github: "renderedtext/elixir-util"},
      {:junit_formatter, "~> 3.1", only: [:test]}
    ]
  end

  defp aliases() do
    [
      "deps.local": ["local.hex --force", "local.rebar --force"],
      "deps.setup": ["deps.local", "deps.get"],
      setup: ["deps.setup", "ecto.setup"]
    ]
  end
end
