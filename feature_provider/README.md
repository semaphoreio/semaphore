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

### Caching

Calling a remote provider on every lookup is slow, so providers are usually cached with `FeatureProvider.CachexCache`. The cache needs a `Cachex` process in the supervision tree:

```elixir
# config.exs
config FeatureProvider, :provider, {MyApp.GrpcProvider, [
  server: "feature_hub:50051",
  cache: {FeatureProvider.CachexCache, name: :feature_cache, ttl_ms: :timer.minutes(15)}
]}

# application.ex
children = [
  {Cachex, name: :feature_cache},
  # ...
]
```

A value is loaded from the provider on a cache miss and kept for `ttl_ms`. By default, once it expires, a failing provider makes every lookup fail with `{:error, {:not_found, _}}`.

#### Serving the last known value (`stale_ttl_ms`)

With `stale_ttl_ms`, the cache also keeps the last value it loaded for each key (for example each organization), for `ttl_ms + stale_ttl_ms` after it was stored. When a load fails, that value is served instead of the error, and a warning is logged. Every successful load replaces it and restarts the window.

```elixir
cache: {FeatureProvider.CachexCache,
        name: :feature_cache, ttl_ms: :timer.minutes(15), stale_ttl_ms: :timer.hours(24)}
```

- A load fails when the provider returns `{:error, _}` (or `:error`), raises, exits or throws. **A provider that turns errors into a successful result, such as `{:ok, []}`, never fails: the empty list replaces the last known value and every feature reads as disabled.** Return `{:error, reason}` from your provider instead.
- A key with no last known value (never loaded, or not loaded within `ttl_ms + stale_ttl_ms`) fails as before. A raise, exit or throw is propagated.
- Invalidating a key (`invalidate: true`) keeps its last known value, so a failing reload can still fall back to it. Clearing the cache drops it.
- `stale_ttl_ms` has to be a positive integer. Any other value disables it.

#### Circuit breaker (`breaker`)

`stale_ttl_ms` keeps lookups working during a provider outage, but every cache miss still calls the provider and waits for it to time out. A provider outage affects all keys at once, so `FeatureProvider.CircuitBreaker` stops calling it for the whole service:

```elixir
# config.exs
cache: {FeatureProvider.CachexCache,
        name: :feature_cache, stale_ttl_ms: :timer.hours(24), breaker: :feature_breaker}

# application.ex
children = [
  {Cachex, name: :feature_cache},
  {FeatureProvider.CircuitBreaker, name: :feature_breaker}
]
```

1. **Closed**: cache misses call the provider. Each failed load is still served from the last known value; failed loads in a row are counted, and a successful load resets the count.
2. **Open**: after `failure_threshold` (default 3) failed loads in a row, cache misses stop calling the provider. They get the last known value, or fail straight away for a key that has none. Fresh values in the cache are served as usual. `reload: true` doesn't call the provider either.
3. **Probing**: while open, the breaker re-runs the failed load that opened it, in the background; requests never wait for it. The first probe runs after `probe_base_ms` (default 5s), and each failed probe doubles the delay up to `probe_max_ms` (default 60s). Each delay is picked at random between half and all of that value, so pods don't probe the provider at the same moment. A probe still running after `probe_timeout_ms` (default 30s) is killed and counts as failed.
4. A successful probe closes the breaker and stores its result in the cache. Other keys are refreshed on their next cache miss.

The breaker logs when it opens, when a probe fails and when it closes, instead of logging every lookup. Its state is kept in an ETS table, so lookups don't go through the breaker process. Each pod has its own breaker.

Without the `breaker` option, or when the breaker process isn't running, the cache behaves as if there was no breaker. The breaker is useful together with `stale_ttl_ms`. Without it, an open breaker only makes lookups fail faster.

### Other providers

You can implement your own provider by implementing the `FeatureProvider.Provider` behaviour. See example implementations in the [github repository](https://github.com/renderedtext/feature_provider/blob/master/test/providers).

## Development

There are some makefile targets prepare to ease working with the code.
Each target checks if it's running in a docker container. If it is - it executes a plain command, if it's not - it will execute `docker compose` command to set up an environment and run a command.

- `make test` - run tests
- `make docs` - generate documentation in `doc` directory
- `make cover` - generate test coverage report in `cover` directory
