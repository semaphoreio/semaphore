defmodule PublicAPI.Schemas.Stages.StageEvent do
  @moduledoc """
  Schema for a stage event
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    type: :object,
    required: [],
    properties: %{
      id: PublicAPI.Schemas.Common.ResourceId.schema(),
      stage_id: PublicAPI.Schemas.Common.ResourceId.schema(),
      source_id: PublicAPI.Schemas.Common.ResourceId.schema(),
      source_type: %Schema{
        type: :string,
        enum: ~w(STAGE EVENT_SOURCE)
      },
      state: %Schema{
        type: :string,
        enum: ~w(PENDING WAITING_FOR_APPROVAL PROCESSED)
      },
      created_at: PublicAPI.Schemas.Common.timestamp(),
      approved_at: PublicAPI.Schemas.Common.timestamp()
    }
  })
end
