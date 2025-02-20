defmodule Support.StubbedProvider do
  use FeatureProvider.Provider

  @impl FeatureProvider.Provider
  def provide_features(_org_id \\ nil, _opts \\ []) do
    FunRegistry.run!(__MODULE__, :provide_features, [nil, nil])
  end

  @impl FeatureProvider.Provider
  def provide_machines(_org_id \\ nil, _opts \\ []) do
    FunRegistry.run!(__MODULE__, :provide_machines, [])
  end

  def feature(type, traits) do
    traits
    |> Enum.reduce(
      %FeatureProvider.Feature{
        quantity: 0,
        state: :enabled,
        type: type,
        name: type
      },
      fn trait_name, feature ->
        trait(trait_name).(feature)
      end
    )
  end

  defp trait({:quantity, quantity}) do
    fn thing ->
      thing
      |> Map.put(:quantity, quantity)
    end
  end

  defp trait(_), do: & &1
end
