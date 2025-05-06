defmodule PublicAPI.Schemas.Stages.ApprovalCondition do
  @moduledoc """
  Schema for a stage connection data filter
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Stages.ApprovalCondition",
    type: :object,
    nullable: true,
    description:
      "A stage approval condition guarantees that events in the queue are manually approved before they can trigger executions",
    properties: %{
      count: %Schema{
        type: :integer,
        description: "How many approvals are required"
      }
    }
  })
end
