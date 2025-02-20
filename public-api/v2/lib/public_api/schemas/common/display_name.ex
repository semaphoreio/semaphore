defmodule PublicAPI.Schemas.Common.DisplayName do
  @moduledoc """
  Schema for a name
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "DisplayName",
    type: :string,
    description: "Name of a resource",
    example: "My name",
    minLength: 1
  })
end
