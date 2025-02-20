defmodule Front.Models.Billing.SpendingItem do
  alias InternalApi.Billing.SpendingItem, as: GrpcSpendingItem
  alias __MODULE__

  defstruct [
    :name,
    :display_name,
    :display_description,
    :units,
    :unit_price,
    :total_price,
    trends: [],
    tiers: []
  ]

  @type trend :: %{
          name: String.t(),
          usage: integer(),
          price: String.t()
        }

  @type t :: %SpendingItem{
          name: String.t(),
          display_name: String.t(),
          display_description: String.t(),
          units: integer(),
          trends: [trend()],
          unit_price: String.t(),
          total_price: String.t(),
          tiers: [SpendingItem.t()]
        }

  def new(params), do: struct(SpendingItem, params)

  def from_grpc(spending_item = %GrpcSpendingItem{}) do
    new(
      name: spending_item.name,
      display_name: spending_item.display_name,
      display_description: spending_item.display_description,
      units: spending_item.units,
      unit_price: spending_item.unit_price,
      total_price: spending_item.total_price,
      trends: trends_from_grpc(spending_item.trends)
    )
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

  @spec combine_items([t()]) :: [t()]
  def combine_items(items) when length(items) > 1 do
    items
    |> Enum.find(&(&1.unit_price == ""))
    |> case do
      nil ->
        items

      root_item ->
        [%{root_item | tiers: items -- [root_item]}]
    end
  end

  def combine_items(items), do: items
end
