defmodule E2E.MixProject do
  use Mix.Project

  def project do
    [
      app: :e2e,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  defp elixirc_paths(:test) do
    base = ["lib", "test/support"]
    if System.get_env("START_WALLABY") do
      base
    else
      # Exclude ui_test_case.ex if Wallaby is not available
      ["lib", "test/support"]
      |> Enum.flat_map(fn path ->
        if path == "test/support" do
          Path.wildcard("test/support/*.ex")
          |> Enum.reject(&(&1 =~ "ui_test_case.ex"))
        else
          [path]
        end
      end)
    end
  end

  defp elixirc_paths(:dev), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    deps = [
      {:junit_formatter, "~> 3.3"},
      {:jason, "~> 1.4"},
      {:uuid, "~> 1.1"},
      {:mox, "~> 1.0", only: :test},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false},
      {:excoveralls, "~> 0.14", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_unit_notifier, "~> 0.1", only: :test},
      {:nimble_totp, "~> 1.0.0"},
      {:tentacat, "~> 2.2"},
      {:tesla, "~> 1.7"},
      {:ex_doc, "~> 0.30", only: :dev, runtime: false},
      {:dialyxir, "~> 1.3", only: [:dev, :test], runtime: false}
    ]

    if System.get_env("START_WALLABY") do
      deps ++ [{:wallaby, "~> 0.23.0"}]
    else
      deps
    end
  end
end
