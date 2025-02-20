defmodule PublicAPI.Schemas.Pipelines.DescribeResponse do
  @moduledoc """
  Schema for the response of Pipelines.Describe operation.
  """
  alias OpenApiSpex.{Reference, Schema}
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "Pipelines.DescribeResp",
    description: "Pipeline describe response containg pipeline info and contained blocks info",
    type: :object,
    properties: %{
      pipeline: %Reference{"$ref": "#/components/schemas/Pipelines.Pipeline"},
      blocks: %Schema{
        type: :array,
        items: %Reference{"$ref": "#/components/schemas/Pipelines.Block"}
      }
    }
  })
end
