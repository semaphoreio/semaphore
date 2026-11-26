defmodule EnvVarPolicy.MixProject do
  use Mix.Project

  def project do
    [
      app: :env_var_policy,
      version: "0.1.0",
      elixir: "~> 1.11",
      elixirc_options: [warnings_as_errors: true],
      deps: []
    ]
  end

  def application do
    []
  end
end
