defmodule PublicAPI.Schemas.DeploymentTargets.UpdateRequest do
  @moduledoc """
  Schema for a deployment target update request.
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "DeploymentTargets.UpdateRequest",
    type: :object,
    required: [:unique_token, :deployment_target],
    properties: %{
      deployment_target: %OpenApiSpex.Reference{
        "$ref": "#/components/schemas/DeploymentTargets.DeploymentTarget"
      },
      unique_token: %Schema{
        type: :string,
        description: "The unique idempotency UUID."
      }
    }
  })
end
