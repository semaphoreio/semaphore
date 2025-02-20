defmodule Front.Models.Billing.ProjectSpending do
  alias __MODULE__

  alias InternalApi.Billing.Project, as: GrpcProject

  alias Front.Models.Billing.SpendingGroup

  defstruct [
    :project_id,
    :project_name,
    :workflow_count,
    :total_price,
    workflow_trends: [],
    groups: []
  ]

  @type t :: %ProjectSpending{
          project_id: String.t(),
          project_name: String.t(),
          workflow_count: non_neg_integer(),
          workflow_trends: [SpendingGroup.trend()],
          total_price: String.t(),
          groups: [SpendingGroup.t()]
        }

  @spec from_grpc(GrpcProject.t()) :: t()
  def from_grpc(project = %GrpcProject{}) do
    groups =
      project.cost.spending_groups
      |> Enum.map(&SpendingGroup.from_grpc(&1))

    workflow_trends =
      Enum.map(project.cost.workflow_trends, fn trend ->
        %{
          name: trend.name,
          usage: trend.units,
          price: trend.price
        }
      end)

    new(
      project_id: project.id,
      project_name: project.name,
      workflow_count: project.cost.workflow_count,
      total_price: project.cost.total_price,
      workflow_trends: workflow_trends,
      groups: groups
    )
  end

  def new(params), do: struct(ProjectSpending, params)

  @doc """
  Returns spending in the CSV format.
  """
  @spec to_csv([GrpcProject.t()]) :: String.t()
  def to_csv(project_spendings) do
    header = [:project_name, :type, :price]

    spending_groups =
      project_spendings
      |> Enum.flat_map(fn project_spending ->
        project_spending.cost.spending_groups
        |> Enum.map(fn spending_group ->
          [project_spending.name, spending_group.type, spending_group.total_price]
        end)
      end)

    workflow_count =
      Enum.map(project_spendings, fn project_spending ->
        [project_spending.name, "workflow_count", project_spending.cost.workflow_count]
      end)

    ([header] ++ spending_groups ++ workflow_count)
    |> CSV.encode()
    |> Enum.to_list()
    |> to_string()
  end
end
