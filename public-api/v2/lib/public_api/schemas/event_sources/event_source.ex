defmodule PublicAPI.Schemas.EventSources.EventSource do
  @moduledoc """
  Schema for a event source

  format:
  apiVersion: (v2)
  kind: EventSource
  metadata: (id, org_id, timestamps)*readonly
  spec: duplication of metadata + resource-specific stuff
  """
  use PublicAPI.SpecHelpers.Schema

  use PublicAPI.Schemas.Common.Kind, kind: "EventSource"

  OpenApiSpex.schema(%{
    title: "EventSource",
    type: :object,
    required: [:apiVersion, :kind, :metadata, :spec],
    properties: %{
      apiVersion: PublicAPI.Schemas.Common.ApiVersion.schema(),
      kind: ResourceKind.schema(),
      metadata: %Schema{
        type: :object,
        required: [:name, :canvas],
        description: "Metadata of the event sources, all fields are read only",
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
          },
          status: %Schema{
            type: :object,
            nullable: true,
            description: "Status of the event source",
            properties: %{
              key: %Schema{
                type: :string,
                nullable: true,
                description: "Key used to sign the events",
                example: "..."
              }
            }
          }
        },
        readOnly: true
      },

      #
      # TODO: right now we don't have anything in the spec, but it might change in the future
      #
      spec: %Schema{
        type: :object,
        description: "Specification of the event source",
        required: [],
        properties: %{}
      }
    }
  })
end
