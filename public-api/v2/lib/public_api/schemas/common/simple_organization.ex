defmodule PublicAPI.Schemas.Common.SimpleOrganization do
  @moduledoc """
  Schema for a organization
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "SimpleOrganization",
    type: :object,
    description: "Simple Organization object",
    properties: %{
      id: PublicAPI.Schemas.Common.ResourceId.schema(),
      name: PublicAPI.Schemas.Common.NullableName.schema()
    }
  })
end
