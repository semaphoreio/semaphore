defmodule PublicAPI.Schemas.Workflows.ScheduleResponse do
  @moduledoc """
  Schema for the response of the Workflows.Schedule operation.
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Workflows.ScheduleResponse",
    type: :object,
    properties: %{
      wf_id: PublicAPI.Schemas.Common.id("Workflow"),
      ppl_id: PublicAPI.Schemas.Common.id("Pipeline"),
      hook_id: PublicAPI.Schemas.Common.id("Hook")
    }
  })
end
