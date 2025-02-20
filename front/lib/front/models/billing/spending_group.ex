defmodule Front.Models.Billing.SpendingGroup do
  alias Front.Models.Billing.SpendingItem
  alias InternalApi.Billing.SpendingGroup, as: GrpcSpendingGroup
  alias __MODULE__

  defstruct [:type, :total_price, items: [], trends: []]

  @type spending_type ::
          :unspecified | :machine_time | :seats | :storage | :addons | :machine_capacity

  @type trend :: %{
          name: String.t(),
          usage: integer(),
          price: String.t()
        }

  @type t :: %SpendingGroup{
          type: spending_type(),
          total_price: String.t(),
          items: [SpendingItem.t()],
          trends: [trend()]
        }

  def new(params), do: struct(SpendingGroup, params)

  def from_grpc(spending_group = %GrpcSpendingGroup{}) do
    items =
      spending_group.items
      |> Enum.map(&SpendingItem.from_grpc/1)
      |> Enum.group_by(& &1.name)
      |> Enum.flat_map(fn {_name, items} -> SpendingItem.combine_items(items) end)

    new(
      type: status_from_grpc(spending_group.type),
      total_price: spending_group.total_price,
      items: items,
      trends: trends_from_grpc(spending_group.trends)
    )
  end

  def empty?(spending_group = %SpendingGroup{}) do
    spending_group.items == []
  end

  @spec status_from_grpc(InternalApi.Billing.SpendingType.t()) :: spending_type()
  defp status_from_grpc(value) do
    value
    |> InternalApi.Billing.SpendingType.key()
    |> case do
      :SPENDING_TYPE_MACHINE_TIME -> :machine_time
      :SPENDING_TYPE_SEAT -> :seats
      :SPENDING_TYPE_STORAGE -> :storage
      :SPENDING_TYPE_ADDON -> :addons
      :SPENDING_TYPE_MACHINE_CAPACITY -> :machine_capacity
      _ -> :unspecified
    end
  end

  def trends_from_grpc(trends) do
    Enum.map(trends, fn trend ->
      %{
        name: trend.name,
        usage: trend.units,
        price: trend.price
      }
    end)
  end
end
