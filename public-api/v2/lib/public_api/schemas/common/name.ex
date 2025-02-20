defmodule PublicAPI.Schemas.Common.Name do
  @moduledoc """
  Schema for a name
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Name",
    type: :string,
    description: "Name that can be used in the url",
    example: "my-name",
    minLength: 1,
    pattern: ~r/\A(?!-)[a-z0-9\-]+\z/
  })
end
