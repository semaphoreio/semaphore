defmodule ParameterizedProvider do
  @moduledoc false
  use FeatureProvider.Provider

  @impl FeatureProvider.Provider
  def provide_features("id-1", _opts) do
    {:ok, []}
  end

  def provide_features("id-2", _opts) do
    {:ok, [%FeatureProvider.Feature{name: "A feature.", type: "a-feature-type"}]}
  end

  @impl FeatureProvider.Provider
  def provide_machines(_param, _opts) do
    raise "oops"
  end
end
