# FeatureProvider

FeatureProvider is a library that provides a way to fetch features and machines from different sources, and provide abstractions for working them.

## Installation

```elixir
def deps do
  [
    {:feature_provider, path: "../feature_provider"}
  ]
end
```

## Configuration

To use the library, you need to set a provider. A provider is a module that implements the `FeatureProvider.Provider` behaviour:

```elixir
defmodule MyProvider do
  use FeatureProvider.Provider

  @impl FeatureProvider.Provider
  def provide_features(_param, _opts) do
    {:ok, [%FeatureProvider.Feature{}]}
  end

  @impl FeatureProvider.Provider
  def provide_machines(_param, _opts) do
    {:ok, [%FeatureProvider.Machine{}]}
  end
end
```

You can use your provider directly:

```elixir
FeatureProvider.find_feature("some_feature", provider: MyProvider)
```

Or by setting a `:provider` config value:

```elixir
# config.exs
config FeatureProvider, :provider, MyProvider

# then in the code
FeatureProvider.find_feature("some_feature")
```

If your provider needs a context - like organization id, that you want to pass to the provider, you can use the `:param` option:

```elixir
defmodule MyProvider do
  use FeatureProvider.Provider

  @impl FeatureProvider.Provider
  def provide_features(org_id, _opts) do
    # Fetch features by `org_id`
  end

  @impl FeatureProvider.Provider
  def provide_machines(org_id, _opts) do
    # Fetch machines by `org_id`
  end
end

# then pass org id as a `:param` option
FeatureProvider.find_feature("some_feature", param: org_id)
# `param` is `nil` by default
FeatureProvider.find_feature("some_feature")
```

## Usage

### YAML provider configuration

`FeatureProvider.YamlProvider` is a built-in provider that fetches features from a yaml file. And stores them internally in an agent.
Due to the fact that the agent is used, we need to add it to the supervision tree.

```elixir
# config.ex
config FeatureProvider, :provider, {FeatureProvider.YamlProvider, [
  # path to the yaml file
  yaml_path: "path/to/features.yaml",
  # name of the agent process that will hold the features
  agent_name: :yaml_feature_provider
]}

# application.ex
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      # ...
      Application.get_env(FeatureProvider, :provider)
    ]

    opts = [strategy: :one_for_one]
    Supervisor.start_link(children, opts)
  end
end


# then in the code
FeatureProvider.find_feature("some_feature")
```

To see changes in the yaml file, you need to restart the application.

### API providers

In real-world scenarios, you will probably want to fetch features from a remote service.

For instance, this is how you can implement a provider that fetches features from a gRPC service:

```elixir
defmodule MyApp.GrpcProvider do
  use FeatureProvider.Provider

  @impl FeatureProvider.Provider
  def provide_features(org_id, opts) do
    # Fetch `:server` from the options. If it's not set, raise an error.
    server = Keyword.fetch_lazy(opts, :server, fn ->
      raise "server is not set"
    end)

    timeout = Keyword.get(opts, :timeout, 10_000)

    # Fetch features from a service.
    {:ok, response} = MyApp.FeatureHubClient.find_features(org_id, server: server, timeout: timeout)
    # Build features from the response
    features = Enum.map(response.features, &build_feature/1)
    # Return the features
    {:ok, features}
  end

  @impl FeatureProvider.Provider
  def provide_machines(_org_id, _opts) do
    {:ok, []}
  end


  @spec build_feature(any) :: FeatureProvider.Feature.t()
  def build_feature(grpc_feature) do
    # build the feature from a grpc feature
  end
end
```

Now, you can use the provider in your application:

```elixir

# config.exs
config FeatureProvider, :provider, {MyApp.GrpcProvider, [timeout: 10_000, server: "feature_hub:50051"]}

# then in the code
FeatureProvider.find_feature("some_feature", param: org_id)
```

### Other providers

You can implement your own provider by implementing the `FeatureProvider.Provider` behaviour. See example implementations in the [github repository](https://github.com/renderedtext/feature_provider/blob/master/test/providers).

## Development

There are some makefile targets prepare to ease working with the code.
Each target checks if it's running in a docker container. If it is - it executes a plain command, if it's not - it will execute `docker compose` command to set up an environment and run a command.

- `make test` - run tests
- `make docs` - generate documentation in `doc` directory
- `make cover` - generate test coverage report in `cover` directory
