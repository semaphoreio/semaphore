defmodule PublicAPI.Schemas.Pipelines.PartialRebuildResponse do
  @moduledoc """
  Schema for the response of Pipelines.Terminate operation.
  """

  alias OpenApiSpex.Schema
  require OpenApiSpex

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      message: %Schema{type: :string},
      pipeline_id: %Schema{type: :string, format: :uuid}
    }
  })
end
