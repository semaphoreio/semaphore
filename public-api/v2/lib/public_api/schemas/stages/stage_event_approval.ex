defmodule PublicAPI.Schemas.Stages.StageEventApproval do
  @moduledoc """
  Schema for a stage event
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Stages.StageEventApproval",
    type: :object,
    required: [:approved_at, :approved_by],
    properties: %{
      approved_at: PublicAPI.Schemas.Common.timestamp(),
      approved_by: PublicAPI.Schemas.Common.ResourceId.schema()
    }
  })
end
