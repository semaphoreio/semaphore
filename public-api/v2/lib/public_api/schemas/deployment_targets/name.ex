defmodule PublicAPI.Schemas.DeploymentTargets.Name do
  @moduledoc """
  Schema for a secret name
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "DeploymentTargets.Name",
    type: :string,
    description:
      "DeploymentTargets name must be unique on project level, must match the name regex: `^[A-Za-z0-9_\.\-]+$`",
    example: "production",
    pattern: ~r/^[A-Za-z0-9_\.\-]+$/,
    minLength: 1
  })
end
