defmodule PublicAPI.Mixfile do
  use Mix.Project

  # Code.compiler_options(on_undefined_variable: :warn)

  def project do
    [
      app: :public_api,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      consolidate_protocols: Mix.env() != :test,
      deps: deps()
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger], mod: {PublicAPI.Application, []}]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:prod), do: ["lib"]
  defp elixirc_paths(_), do: ["lib", "test/support"]

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:grpc, "~> 0.3"},
      {:protobuf, "~> 0.12.0"},
      {:plug_cowboy, "~> 2.0"},
      {:cors_plug, "~> 3.0"},
      {:httpoison, "~> 2.2.0"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:log_tee, github: "renderedtext/log-tee"},
      {:uuid, "~> 1.1"},
      {:tesla, "~> 1.4", only: [:dev, :test], runtime: false},
      {:hackney, "~> 1.17"},
      {:jason, ">= 1.0.0"},
      {:watchman, github: "renderedtext/ex-watchman"},
      {:scrivener_headers, "~> 3.1"},
      {:scrivener, "~> 2.3"},
      {:util, github: "renderedtext/elixir-util"},
      {:wormhole, "~> 2.3", override: true},
      {:yaml_elixir, "~> 2.1"},
      {:grpc_mock, github: "renderedtext/grpc-mock", branch: "grpc08", only: [:dev, :test]},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false},
      {:timex, "~> 3.1"},
      {:ex_crypto, github: "ntrepid8/ex_crypto", ref: "0997a1aaebe701523c0a9b71d4acec4a1819354e"},
      {:faker, "~> 0.17", only: [:dev, :test]},
      {:fun_registry, github: "renderedtext/fun-registry", only: [:dev, :test]},
      {:ecto, "~> 3.11", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.1", only: [:dev], runtime: false},
      {:junit_formatter, "~> 3.1", only: [:test]},
      {:mock, "~> 0.3.0", only: :test},
      {:open_api_spex,
       github: "renderedtext/open_api_spex", ref: "1f4c474b95b7300cdce09cd768e9e4c03f802e42"},
      {:cacheman, github: "renderedtext/ex-cacheman"},
      {:ymlr, "~> 5.0"},
      {:tackle, github: "renderedtext/ex-tackle", tag: "v0.2.3"},
      {:feature_provider, path: "../../feature_provider"},
      {:logger_json, "~> 6.0"},
      {:logger_backends, "~> 1.0.0", only: [:dev]}
    ]
  end

  defp aliases do
    [
      "spec.gen":
        ~w(json yaml)
        |> Enum.map(fn format ->
          "openapi.spec.#{format} --spec PublicAPI.ApiSpec --start-app=false --pretty=true --vendor-extensions=false spec/openapi/openapi.#{format}"
        end)
    ]
  end
end
