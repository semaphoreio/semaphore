defmodule PublicAPI.Schemas.Stages.ListEventsResponse do
  @moduledoc """
  Schema for a deployment targets list response
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Stages.ListEventsResponse",
    type: :array,
    items: PublicAPI.Schemas.Stages.StageEvent.schema()
  })
end
