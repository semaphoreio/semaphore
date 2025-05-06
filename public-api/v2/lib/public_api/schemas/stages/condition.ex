defmodule PublicAPI.Schemas.Stages.Condition do
  @moduledoc """
  Schema for a stage connection
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Stages.Condition",
    type: :object,
    required: [:type],
    description: "A stage condition controls how and when events exit the stage queue",
    properties: %{
      type: %Schema{
        type: :string,
        enum: ~w(APPROVAL TIME_WINDOW),
        description: "The type of condition"
      },
      approval: PublicAPI.Schemas.Stages.ApprovalCondition.schema(),
      time_window: PublicAPI.Schemas.Stages.TimeWindowCondition.schema()
    }
  })
end
