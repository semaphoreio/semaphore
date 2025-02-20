defmodule PublicAPI.Schemas.Tasks.ListResponse do
  @moduledoc """
  Schema for the list response operation
  """
  use PublicAPI.SpecHelpers.Schema
  use PublicAPI.Schemas.Common.Kind, kind: "Task"

  OpenApiSpex.schema(%{
    title: "Tasks.ListResponse",
    type: :array,
    items: PublicAPI.Schemas.Tasks.Task.schema()
  })
end
