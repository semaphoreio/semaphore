defmodule PublicAPI.Schemas.DeploymentTargets.CordonResponse do
  @moduledoc """
  Schema for activate/deactivate (cordon) responses
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "DeploymentTargets.CordonResponse",
    type: :object,
    properties: %{
      id: PublicAPI.Schemas.Common.id("DeploymentTarget"),
      state: %Schema{
        type: :string,
        enum: ~w(USABLE CORDONED),
        description:
          ~s(State of the deployment target, `CORDONED` deployment target is an deactivated deployment target.
           Deployment Target in `USABLE` state can be used or modified.)
      }
    }
  })
end
