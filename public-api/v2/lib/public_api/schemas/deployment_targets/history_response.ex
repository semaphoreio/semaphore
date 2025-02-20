defmodule PublicAPI.Schemas.DeploymentTargets.HistoryResponse do
  @moduledoc """
  Schema for a Deployment target history response.
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "DeploymentTargets.HistoryResponse",
    type: :array,
    items: %OpenApiSpex.Reference{
      "$ref": "#/components/schemas/DeploymentTargets.HistoryItem"
    }
  })
end
