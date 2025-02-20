defmodule PublicAPI.Schemas.Workflows.RescheduleResponse do
  @moduledoc """
  Schema for the response of the Workflows.Reschedule operation.
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Workflows.RescheduleResponse",
    type: :object,
    properties: %{
      wf_id: PublicAPI.Schemas.Common.id("Workflow"),
      ppl_id: PublicAPI.Schemas.Common.id("Pipeline")
    }
  })
end
