defmodule PublicAPI.Schemas.Stages.StageEvent do
  @moduledoc """
  Schema for a stage event
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Stages.StageEvent",
    type: :object,
    required: [:id, :source_id, :source_type, :state, :created_at],
    properties: %{
      id: PublicAPI.Schemas.Common.ResourceId.schema(),
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
      approved_at: %Schema{
        type: :string,
        format: :"date-time",
        nullable: true
      }
    }
  })
end
