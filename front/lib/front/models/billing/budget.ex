defmodule Front.Models.Billing.Budget do
  alias InternalApi.Billing.Budget, as: GrpcBudget
  alias __MODULE__

  defstruct [:limit, :email, :default_email]

  @type t :: %Budget{
          limit: String.t(),
          email: String.t(),
          default_email: String.t()
        }

  @spec new(Enum.t()) :: t()
  def new(params \\ %{}), do: struct(Budget, params)

  @spec from_grpc(GrpcBudget.t()) :: t()
  def from_grpc(budget = %GrpcBudget{}) do
    new(
      limit: budget.limit,
      email: budget.email,
      default_email: ""
    )
  end
end
