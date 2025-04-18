defmodule PublicAPI.Schemas.EventSources.ListResponse do
  @moduledoc """
  Schema for a event source list response
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "EventSources.ListResponse",
    type: :array,
    items: PublicAPI.Schemas.EventSources.EventSource.schema()
  })
end
