defmodule Front.Models.Billing.ProjectCost do
  alias __MODULE__

  alias InternalApi.Billing.ProjectCost, as: GrpcProjectCost

  alias Front.Models.Billing.SpendingGroup

  defstruct [
    :from_date,
    :to_date,
    :total_price,
    :workflow_count,
    :workflow_trends,
    :spending_groups
  ]

  @type t :: %ProjectCost{
          from_date: String.t(),
          to_date: String.t(),
          total_price: String.t(),
          workflow_count: non_neg_integer(),
          workflow_trends: [SpendingGroup.trend()],
          spending_groups: [SpendingGroup.t()]
        }

  @spec from_grpc(GrpcProjectCost.t()) :: t()
  def from_grpc(project_cost = %GrpcProjectCost{}) do
    groups =
      project_cost.spending_groups
      |> Enum.map(&SpendingGroup.from_grpc(&1))

    workflow_trends =
      Enum.map(project_cost.workflow_trends, fn trend ->
        %{
          name: trend.name,
          usage: trend.units,
          price: trend.price
        }
      end)

    new(
      from_date: Timex.from_unix(project_cost.from_date.seconds),
      to_date: Timex.from_unix(project_cost.to_date.seconds),
      total_price: project_cost.total_price,
      workflow_count: project_cost.workflow_count,
      workflow_trends: workflow_trends,
      spending_groups: groups
    )
  end

  def new(params), do: struct(ProjectCost, params)
end
