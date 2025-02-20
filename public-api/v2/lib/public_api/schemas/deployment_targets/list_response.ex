defmodule PublicAPI.Schemas.DeploymentTargets.ListResponse do
  @moduledoc """
  Schema for a deployment targets list response
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "DeploymentTargets.ListResponse",
    type: :array,
    items: PublicAPI.Schemas.DeploymentTargets.DeploymentTarget.schema()
  })
end
