defmodule PublicAPI.Schemas.Common.Contributor do
  @moduledoc """
  Schema for a git contributor (git handle)
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Contributor",
    description: "Contributor handle",
    type: :string
  })
end
