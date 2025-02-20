defmodule PublicAPI.Schemas.Tasks.Task do
  @moduledoc """
  Schema for the Task entity
  """
  use PublicAPI.SpecHelpers.Schema
  use PublicAPI.Schemas.Common.Kind, kind: "Task"

  OpenApiSpex.schema(%{
    title: "Tasks.Task",
    type: :object,
    properties: %{
      apiVersion: PublicAPI.Schemas.Common.ApiVersion.schema(),
      kind: ResourceKind.schema(),
      metadata: PublicAPI.Schemas.Tasks.Metadata.schema(),
      spec: PublicAPI.Schemas.Tasks.Spec.schema()
    }
  })
end
