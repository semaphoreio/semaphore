defmodule Front.Models.Billing.Project do
  alias __MODULE__

  alias InternalApi.Billing.Project, as: GrpcProject

  alias Front.Models.Billing.ProjectCost

  defstruct [
    :id,
    :name,
    :cost
  ]

  @type t :: %Project{
          id: String.t(),
          name: String.t(),
          cost: ProjectCost.t()
        }

  @spec from_grpc(GrpcProject.t()) :: t()
  def from_grpc(project = %GrpcProject{}) do
    new(
      id: project.id,
      name: project.name,
      cost: ProjectCost.from_grpc(project.cost)
    )
  end

  def new(params), do: struct(Project, params)
end
