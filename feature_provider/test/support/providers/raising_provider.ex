defmodule RaisingProvider do
  @moduledoc false
  use FeatureProvider.Provider

  @impl FeatureProvider.Provider
  def provide_features(_param, _opts) do
    {:ok, []}
  end

  @impl FeatureProvider.Provider
  def provide_machines(_param, _opts) do
    raise "oops"
  end
end
