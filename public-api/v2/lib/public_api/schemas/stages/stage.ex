defmodule PublicAPI.Schemas.Stages.Stage do
  @moduledoc """
  Schema for a stage

  format:
  apiVersion: (v2)
  kind: Stage
  metadata: (id, org_id, timestamps)*readonly
  spec: duplication of metadata + resource-specific stuff
  """
  use PublicAPI.SpecHelpers.Schema

  use PublicAPI.Schemas.Common.Kind, kind: "Stage"

  OpenApiSpex.schema(%{
    title: "Stage",
    type: :object,
    required: [:apiVersion, :kind, :metadata, :spec],
    properties: %{
      apiVersion: PublicAPI.Schemas.Common.ApiVersion.schema(),
      kind: ResourceKind.schema(),
      metadata: %Schema{
        type: :object,
        description: "Metadata of the stages, all fields are read only",
        required: [:name, :canvas],
        properties: %{
          id: PublicAPI.Schemas.Common.ResourceId.schema(),
          name: PublicAPI.Schemas.Common.Name.schema(),
          canvas: PublicAPI.Schemas.Common.SimpleCanvas.schema(),
          organization: PublicAPI.Schemas.Common.SimpleOrganization.schema(),
          timeline: %Schema{
            type: :object,
            properties: %{
              created_at: PublicAPI.Schemas.Common.timestamp(),
              created_by: PublicAPI.Schemas.Common.Requester.schema()
            }
          }
        },
        readOnly: true
      },
      spec: %Schema{
        type: :object,
        description: "Specification of the stage",
        required: [:conditions, :connections, :run, :use],
        properties: %{
          use: PublicAPI.Schemas.Stages.TagUsageDefinition.schema(),
          conditions: %Schema{
            type: :array,
            items: PublicAPI.Schemas.Stages.Condition.schema()
          },
          connections: %Schema{
            type: :array,
            items: PublicAPI.Schemas.Stages.Connection.schema()
          },
          run: PublicAPI.Schemas.Stages.RunTemplate.schema()
        }
      }
    }
  })
end
