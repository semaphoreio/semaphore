defmodule PublicAPI.Schemas.Common.ResourceId do
  @moduledoc """
  Schema for a resource id
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Resource Id",
    type: :string,
    format: :uuid,
    example: UUID.uuid4()
  })
end
