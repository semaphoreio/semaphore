defmodule Front.Models.Billing.Cost do
  alias Front.Models.Billing.SpendingItem
  alias InternalApi.Billing.DailyCost, as: GrpcDailyCost
  alias __MODULE__

  defstruct [:type, :price_for_the_day, :price_up_to_the_day, :day, :prediction, items: []]

  @type t :: %Cost{
          type: String.t(),
          price_for_the_day: String.t(),
          price_up_to_the_day: String.t(),
          day: Date.t(),
          prediction: boolean(),
          items: [SpendingItem.t()]
        }

  @spec new(Enum.t()) :: t()
  def new(params \\ %{}), do: struct(Cost, params)

  @spec from_grpc(GrpcDailyCost.t()) :: t()
  def from_grpc(cost = %GrpcDailyCost{}) do
    new(
      type: status_from_grpc(cost.type),
      price_for_the_day: cost.price_for_the_day,
      price_up_to_the_day: cost.price_up_to_the_day,
      day: Timex.from_unix(cost.day.seconds),
      prediction: cost.prediction,
      items: Enum.map(cost.items, &SpendingItem.from_grpc(&1))
    )
  end

  @spec status_from_grpc(InternalApi.Billing.SpendingType.t()) :: atom()
  defp status_from_grpc(value) do
    value
    |> InternalApi.Billing.SpendingType.key()
    |> case do
      :SPENDING_TYPE_MACHINE_TIME -> :machine_time
      :SPENDING_TYPE_SEAT -> :seats
      :SPENDING_TYPE_STORAGE -> :storage
      :SPENDING_TYPE_ADDON -> :addons
      _ -> :unspecified
    end
  end
end
