defmodule ConfigurableProvider do
  @moduledoc false
  use FeatureProvider.Provider

  @impl FeatureProvider.Provider
  def provide_features(_param, opts) do
    features = Keyword.get(opts, :features, [])

    {:ok, features}
  end

  @impl FeatureProvider.Provider
  def provide_machines(_param, opts) do
    machines = Keyword.get(opts, :machines, [])

    {:ok, machines}
  end
end
