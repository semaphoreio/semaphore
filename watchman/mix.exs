defmodule Watchman.MixProject do
  use Mix.Project

  def project do
    [
      app: :watchman,
      version: "0.0.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: []
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end
end
