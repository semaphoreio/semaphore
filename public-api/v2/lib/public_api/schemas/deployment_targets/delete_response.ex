defmodule PublicAPI.Schemas.DeploymentTargets.DeleteResponse do
  @moduledoc """
  Schema for delete action response
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "DeploymentTargets.DeleteResponse",
    type: :object,
    properties: %{
      id: PublicAPI.Schemas.Common.id("DeploymentTarget")
    }
  })
end
