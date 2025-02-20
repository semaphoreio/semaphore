defmodule PublicAPI.Schemas.Workflows.ListResponse do
  @moduledoc """
  Schema for the response of the Workflows.List operation.
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Workflows.ListResponse",
    description:
      "Workflow list. Follow the link headers for fetching additional pages of results",
    type: :array,
    items: PublicAPI.Schemas.Workflows.Workflow.schema()
  })
end
