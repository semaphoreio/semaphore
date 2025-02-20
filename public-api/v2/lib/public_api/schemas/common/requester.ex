defmodule PublicAPI.Schemas.Common.Requester do
  @moduledoc """
  Schema for a requester
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Requester",
    type: :object,
    nullable: true,
    properties: %{
      id: PublicAPI.Schemas.Common.id("Requester"),
      name: PublicAPI.Schemas.Common.DisplayName.schema(),
      type: %Schema{type: :string, description: "Type of the requester", example: "USER"}
    }
  })
end
