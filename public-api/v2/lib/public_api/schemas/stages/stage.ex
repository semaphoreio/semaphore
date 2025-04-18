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
        readOnly: true,
        required: [:id, :organization, :canvas, :name, :timeline]
      },
      spec: %Schema{
        type: :object,
        description: "Specification of the stage",
        required: [:approval_required, :connections, :run_template],
        properties: %{
          approval_required: %Schema{
            type: :boolean,
            description: "Require manual approval to trigger executions",
            default: true
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
