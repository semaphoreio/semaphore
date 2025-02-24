defmodule FeatureProvider.MixProject do
  use Mix.Project

  def project do
    [
      app: :feature_provider,
      version: "0.2.0",
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: [warnings_as_errors: true],
      # Docs
      name: "FeatureProvider",
      description: "FeatureProvider is a library for fetching semaphore features and machines from a provider",
      source_url: "https://github.com/renderedtext/feature_provider",
      docs: docs(),

      # Coverage
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        test: :test,
        "coveralls.lcov": :dev
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:yaml_elixir, ">= 2.0.0"},
      {:cachex, ">= 3.0.0"},
      {:mox, "~> 1.0", only: :test},
      {:ex_doc, "~> 0.27", only: :test, runtime: false},
      {:excoveralls, "~> 0.10", only: :test},
      {:junit_formatter, "~> 3.3", only: [:test]}
    ]
  end

  defp docs() do
    [
      main: "readme",
      source_ref: "master",
      extras: ["README.md"],
      groups_for_modules: [
        Providers: [
          FeatureProvider.YamlProvider
        ],
        Caches: [
          FeatureProvider.CachexCache
        ],
        Behaviours: [
          FeatureProvider.Provider,
          FeatureProvider.Cache
        ]
      ]
    ]
  end
end
