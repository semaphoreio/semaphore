defmodule PublicAPI.Schemas.Tasks.Triggers.Trigger do
  @moduledoc """
  Schema for the Task Trigger object value
  """
  use PublicAPI.SpecHelpers.Schema
  use PublicAPI.Schemas.Common.Kind, kind: "TaskTrigger"

  OpenApiSpex.schema(%{
    title: "Task.Trigger",
    description: "Task Trigger",
    type: :object,
    properties: %{
      apiVersion: PublicAPI.Schemas.Common.ApiVersion.schema(),
      kind: ResourceKind.schema(),
      metadata: PublicAPI.Schemas.Tasks.Triggers.Metadata.schema(),
      spec: PublicAPI.Schemas.Tasks.Triggers.Spec.schema()
    },
    required: [:apiVersion, :kind, :metadata, :spec]
  })
end
