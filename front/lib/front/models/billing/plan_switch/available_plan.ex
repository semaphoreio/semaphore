defmodule Front.Models.Billing.PlanSwitch.AvailablePlan do
  alias Front.Models.Billing.PlanSwitch

  @type t :: %__MODULE__{
          name: String.t(),
          type: PlanSwitch.plan_type(),
          description: String.t(),
          contact_required: boolean(),
          features: PlanSwitch.Features.t()
        }

  defstruct name: "",
            type: :undefined,
            description: "",
            contact_required: false,
            features: %PlanSwitch.Features{}

  @spec new(Enum.t()) :: t()
  def new(params) do
    params =
      params
      |> Enum.map(fn
        {:features, features} -> {:features, PlanSwitch.Features.new(features)}
        {k, v} -> {k, v}
      end)

    struct(__MODULE__, params)
  end
end
