defmodule PublicAPI.Schemas.Pipelines.ListResponse do
  @moduledoc """
  Schema for the response of the Pipelines.List operation.
  """
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "Pipelines.ListResp",
    description:
      "Pipelines list. Follow the link headers for fetching additional pages of results",
    type: :array,
    items: PublicAPI.Schemas.Pipelines.Pipeline.schema()
  })
end
