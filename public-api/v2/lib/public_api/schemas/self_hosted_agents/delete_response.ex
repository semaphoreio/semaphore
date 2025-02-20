defmodule PublicAPI.Schemas.SelfHostedAgents.DeleteResponse do
  @moduledoc """
  Schema for delete response from self-hosted hub
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "SelfHostedAgents.OperationResponse",
    type: :object,
    description: "Message about success of the operation",
    required: [],
    properties: %{
      message: %Schema{
        type: :string,
        description: "Message about success of the operation",
        example: "Agent type deleted successfully"
      }
    }
  })
end
