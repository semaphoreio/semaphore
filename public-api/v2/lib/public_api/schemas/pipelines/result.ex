defmodule PublicAPI.Schemas.Pipelines.Result do
  @moduledoc """
  Schema for the pipeline/block result fields.
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Pipelines.Result",
    type: :string,
    description: "Result state",
    enum: ["PASSED", "STOPPED", "CANCELED", "FAILED"]
  })
end
