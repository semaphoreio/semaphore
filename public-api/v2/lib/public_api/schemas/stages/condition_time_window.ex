defmodule PublicAPI.Schemas.Stages.TimeWindowCondition do
  @moduledoc """
  Schema for a stage connection data filter
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Stages.TimeWindowCondition",
    type: :object,
    nullable: true,
    description:
      "A time window condition guarantees that events only exit the stage queue during certain periods of time",
    properties: %{
      start: %Schema{
        type: :string,
        description: "Start of the time window in HH:MM format"
      },
      end: %Schema{
        type: :string,
        description: "End of the time window in HH:MM format"
      },
      week_days: %Schema{
        type: :array,
        items: %Schema{
          type: :string,
          enum: ~w(Monday Tuesday Wednesday Thursday Friday Saturday Sunday),
          description: "The week days allowed"
        }
      }
    }
  })
end
