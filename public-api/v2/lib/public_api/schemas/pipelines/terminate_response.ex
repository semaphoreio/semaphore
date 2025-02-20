defmodule PublicAPI.Schemas.Pipelines.TerminateResponse do
  @moduledoc """
  Schema for the response of Pipelines.Terminate operation.
  """

  alias OpenApiSpex.Schema
  require OpenApiSpex

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      message: %Schema{
        type: :string,
        description:
          "Message confirming the success of the operation. You can rely on status code for successful termination.",
        example: "Pipeline {id} terminated successfully."
      }
    }
  })
end
