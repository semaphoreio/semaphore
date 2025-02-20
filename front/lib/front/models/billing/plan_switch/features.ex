defmodule Front.Models.Billing.PlanSwitch.Features do
  @type t :: %__MODULE__{
          parallelism: integer(),
          max_users: integer(),
          max_self_hosted_agents: integer(),
          cloud_minutes: integer(),
          seat_cost: number(),
          large_resource_types: boolean(),
          priority_support: boolean()
        }

  defstruct parallelism: 0,
            max_users: 0,
            max_self_hosted_agents: 0,
            cloud_minutes: 0,
            seat_cost: 0,
            large_resource_types: false,
            priority_support: false

  @spec new(Enum.t()) :: t()
  def new(params \\ %{}), do: struct(__MODULE__, params)
end
