defmodule PublicAPI.Schemas.Projects.ListResponse do
  @moduledoc """
  Schema for projects list response
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Projects.ListResponse",
    type: :array,
    items: PublicAPI.Schemas.Projects.Project.schema()
  })
end
