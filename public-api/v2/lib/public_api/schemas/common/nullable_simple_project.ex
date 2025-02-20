defmodule PublicAPI.Schemas.Common.NullableSimpleProject do
  @moduledoc """
  Schema for a project
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Nullable SimpleProject",
    type: :object,
    description: "Simple Project object",
    nullable: true,
    properties: %{
      id: PublicAPI.Schemas.Common.ResourceId.schema(),
      name: PublicAPI.Schemas.Common.NullableName.schema()
    }
  })
end
