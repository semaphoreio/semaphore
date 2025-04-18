defmodule PublicAPI.Schemas.Stages.ListResponse do
  @moduledoc """
  Schema for a deployment targets list response
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Stages.ListResponse",
    type: :array,
    items: PublicAPI.Schemas.Stages.Stage.schema()
  })
end
