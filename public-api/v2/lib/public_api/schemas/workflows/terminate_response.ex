defmodule PublicAPI.Schemas.Workflows.TerminateResponse do
  @moduledoc """
  Schema for the response of the Workflows.Terminate operation.
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Workflows.TerminateResponse",
    type: :object,
    properties: %{
      message: %Schema{
        type: :string,
        description: "Message indicating the workflow termination status"
      }
    }
  })
end
