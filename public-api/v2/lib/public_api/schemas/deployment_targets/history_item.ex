defmodule PublicAPI.Schemas.DeploymentTargets.HistoryItem do
  @moduledoc """
  Schema for a Deployment target history response.
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "DeploymentTargets.HistoryItem",
    type: :object,
    nullable: true,
    description:
      "A deployment history item contains relevant details about deployments triggered for a deployment target.",
    properties: %{
      triggered_by: PublicAPI.Schemas.Common.User.schema(),
      triggered_at: PublicAPI.Schemas.Common.timestamp(),
      target_name: %Schema{
        type: :string,
        description: "The name of the deployment target"
      },
      target_id: PublicAPI.Schemas.Common.id("DeploymentTarget"),
      state_message: %Schema{
        type: :string,
        description: "The message of the last deployment of the deployment target"
      },
      state: %Schema{
        type: :string,
        enum: ~w(PENDING STARTED FAILED),
        description: "The state of the last deployment of the deployment target"
      },
      origin_pipeline_id: %{PublicAPI.Schemas.Common.id("Pipeline") | nullable: true},
      pipeline_id: %{PublicAPI.Schemas.Common.id("Pipeline") | nullable: true},
      id: PublicAPI.Schemas.Common.id("Deployment"),
      env_vars: %Schema{
        type: :array,
        description: "Environment variables of the deployment target",
        items: %OpenApiSpex.Reference{
          "$ref": "#/components/schemas/Secrets.Secret.EnvVar"
        }
      }
    }
  })
end
