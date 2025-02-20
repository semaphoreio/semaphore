defmodule PublicAPI.Schemas.Common.NullableName do
  @moduledoc """
  Schema for a name
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Nullable Name",
    type: :string,
    description: "Name that can be used in the url",
    example: "my-name",
    minLength: 1,
    pattern: ~r/\A(?!-)[a-z0-9\-]+\z/,
    nullable: true
  })
end
