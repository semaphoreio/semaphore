defmodule Front.Models.Billing.Spending do
  alias InternalApi.Billing.Spending, as: GrpcSpending
  alias __MODULE__

  alias Front.Models.Billing.{
    Plan,
    SpendingGroup,
    SpendingSummary
  }

  defstruct [
    :id,
    :display_name,
    :from,
    :to,
    :plan,
    :summary,
    groups: []
  ]

  @type t :: %Spending{
          id: String.t(),
          display_name: String.t(),
          from: DateTime.t(),
          to: DateTime.t(),
          plan: Plan.t(),
          summary: SpendingSummary.t(),
          groups: [SpendingGroup.t()]
        }

  def new(params), do: struct(Spending, params)

  def from_grpc(grpc_spending = %GrpcSpending{}) do
    spending = %Spending{
      id: grpc_spending.id,
      display_name: grpc_spending.display_name,
      from: Timex.from_unix(grpc_spending.from_date.seconds),
      to: Timex.from_unix(grpc_spending.to_date.seconds),
      plan: Plan.from_grpc(grpc_spending.plan_summary),
      summary: SpendingSummary.from_grpc(grpc_spending.summary)
    }

    groups =
      grpc_spending.groups
      |> Enum.map(&SpendingGroup.from_grpc(&1))
      |> Enum.filter(fn
        spending_group when spending_group.type == :addons ->
          # If plan is eligible for addons - show addons group
          Plan.eligible_for_addons?(spending.plan) or not Enum.empty?(spending_group.items)

        spending_group ->
          # Hide groups that don't have any items
          not Enum.empty?(spending_group.items)
      end)

    %{spending | groups: groups}
  end

  @doc """
  Returns spending in the CSV format.
  """
  @spec to_csv(t()) :: String.t()
  def to_csv(spending = %Spending{}) do
    header = [:type, :name, :units, :unit_price, :total_price]

    spending_groups =
      spending.groups
      |> Enum.flat_map(fn spending_group ->
        spending_group.items
        |> Enum.map(fn spending_item ->
          [
            spending_group.type,
            spending_item.display_name,
            spending_item.units,
            spending_item.unit_price,
            spending_item.total_price
          ]
        end)
      end)

    ([header] ++ spending_groups)
    |> CSV.encode()
    |> Enum.to_list()
    |> to_string()
  end
end
