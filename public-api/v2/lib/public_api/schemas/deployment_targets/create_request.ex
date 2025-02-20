defmodule PublicAPI.Schemas.DeploymentTargets.CreateRequest do
  @moduledoc """
  Schema for a deployment target create request.
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "DeploymentTargets.CreateRequest",
    type: :object,
    required: [:unique_token, :deployment_target],
    properties: %{
      deployment_target: %OpenApiSpex.Reference{
        "$ref": "#/components/schemas/DeploymentTargets.DeploymentTarget"
      },
      unique_token: %Schema{
        type: :string,
        description:
          "The unique value used as an idempotency token.
        If there are multiple requests with the same  `unique_token` values only the first one will be processed,
        and the rest will be disregarded but the response will be 200 OK as if those requests were processed successfully."
      }
    }
  })
end
