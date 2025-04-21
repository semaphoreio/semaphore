defmodule PublicAPI.Schemas.Canvases.Canvas do
  @moduledoc """
  Schema for a canvas

  format:
  apiVersion: (v2)
  kind: Canvas
  metadata: (id, org_id, timestamps)*readonly
  spec: duplication of metadata + resource-specific stuff
  """
  use PublicAPI.SpecHelpers.Schema

  use PublicAPI.Schemas.Common.Kind, kind: "Canvas"

  OpenApiSpex.schema(%{
    title: "Canvas",
    type: :object,
    required: [:apiVersion, :kind, :metadata, :spec],
    properties: %{
      apiVersion: PublicAPI.Schemas.Common.ApiVersion.schema(),
      kind: ResourceKind.schema(),
      metadata: %Schema{
        type: :object,
        description: "Metadata of the canvas, all fields are read only",
        properties: %{
          id: PublicAPI.Schemas.Common.ResourceId.schema(),
          organization: PublicAPI.Schemas.Common.SimpleOrganization.schema(),
          name: PublicAPI.Schemas.Common.Name.schema(),
          timeline: %Schema{
            type: :object,
            properties: %{
              created_at: PublicAPI.Schemas.Common.timestamp(),
              created_by: PublicAPI.Schemas.Common.Requester.schema()
            }
          }
        },
        readOnly: true,
        required: [:name]
      },

      #
      # TODO: right now we don't have anything in the spec, but it might change in the future
      #
      spec: %Schema{
        type: :object,
        description: "Specification of the canvas",
        required: [],
        properties: %{}
      }
    }
  })
end
