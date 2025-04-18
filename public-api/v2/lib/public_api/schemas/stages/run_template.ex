defmodule PublicAPI.Schemas.Stages.RunTemplate do
  @moduledoc """
  Schema for a stage connection
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Stages.RunTemplate",
    type: :object,
    nullable: true,
    description:
      "A run template controls which type of execution to create for events leaving the stage queue",
    properties: %{
      type: %Schema{
        type: :string,
        enum: ~w(SEMAPHORE),
        description: "The type of execution to create"
      },
      semaphore: PublicAPI.Schemas.Stages.RunTemplateSemaphore.schema()
    }
  })
end
