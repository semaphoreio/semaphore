defmodule PublicAPI.Schemas.Common.User do
  @moduledoc """
  Schema for a user
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "User",
    type: :object,
    properties: %{
      id: PublicAPI.Schemas.Common.id("User")
    }
  })
end
